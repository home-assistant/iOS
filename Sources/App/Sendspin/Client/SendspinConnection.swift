import Foundation
import Shared

/// One Sendspin session: the cleartext init exchange, the Noise handshake, and everything that
/// flows through the encrypted channel afterwards.
///
/// The whole class runs on the main actor. Audio decryption and PCM conversion are cheap next to
/// the buffering the protocol asks for, and keeping one thread means the protocol state machine has
/// no locking of its own — the only cross-thread hand-off is into the renderer's queue.
@MainActor
final class SendspinConnection {
    /// The specification's suggested per-phase timeout for the cleartext handshake.
    private static let handshakeTimeout: TimeInterval = 30
    private static let pingInterval: TimeInterval = 20
    /// A burst while the filter converges, then a slower steady cadence.
    private static let timeBurstCount = 12
    private static let timeBurstInterval: TimeInterval = 0.25
    private static let timeSteadyInterval: TimeInterval = 5

    let server: SendspinDiscoveredServer

    var onEvent: ((SendspinConnectionEvent) -> Void)?

    private let identity: SendspinIdentity
    private let credentials: SendspinCredentialsStore
    private let renderer: SendspinAudioRenderer
    private let configuration: SendspinPlayerConfiguration

    private var transport: SendspinWebSocketTransport?
    private var session: SendspinNoiseSession?
    private var reassembler = SendspinFragmentReassembler()
    private var clockFilter = SendspinClockFilter()

    private var receiveTask: Task<Void, Never>?
    private var timeTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?

    private var matchedCategory = "sn"
    private var serverId: String?
    private var activeRoles: Set<SendspinRole> = []
    private var streamFormat: SendspinAudioFormat?
    private var pendingLongTermPsk: SendspinPsk?
    private var isAvailable = false
    /// Set while something outside Sendspin holds the audio output, so a later state update does
    /// not quietly report this player as available again.
    private var isOutputTakenByOtherApp = false
    private var isClosed = false

    private(set) var volume: Int
    private(set) var muted: Bool
    private(set) var outputDelayMilliseconds: Int

    var trustLevel: SendspinTrustLevel {
        matchedCategory == "lt" ? .paired : .unpaired
    }

    var isClockSynchronized: Bool {
        clockFilter.isConverged
    }

    /// The server's clock right now, for turning metadata timestamps into playback positions.
    var currentServerTimeMicroseconds: Int64? {
        guard let snapshot = clockFilter.snapshot else { return nil }
        return Int64(snapshot.serverTime(forLocal: Double(SendspinMonotonicClock.nowMicroseconds())))
    }

    init(
        server: SendspinDiscoveredServer,
        identity: SendspinIdentity,
        credentials: SendspinCredentialsStore,
        renderer: SendspinAudioRenderer,
        configuration: SendspinPlayerConfiguration
    ) {
        self.server = server
        self.identity = identity
        self.credentials = credentials
        self.renderer = renderer
        self.configuration = configuration
        volume = configuration.volume
        muted = configuration.muted
        outputDelayMilliseconds = configuration.outputDelayMilliseconds
    }

    // MARK: - Lifecycle

    func start() async {
        do {
            try await performHandshakeWithinTimeout()
            startClockSynchronization()
            startPing()
            receiveTask = Task { [weak self] in
                await self?.receiveLoop()
            }
        } catch {
            Current.Log.error("Sendspin handshake with \(server.name) failed: \(error)")
            close(reason: nil, error: error)
        }
    }

    /// Closes the session, telling the server why when the socket is still usable.
    func close(reason: SendspinGoodbyeReason?, error: Error? = nil) {
        guard !isClosed else { return }
        isClosed = true

        if let reason, session != nil {
            try? send(.clientGoodbye(reason))
        }

        receiveTask?.cancel()
        timeTask?.cancel()
        pingTask?.cancel()
        receiveTask = nil
        timeTask = nil
        pingTask = nil

        renderer.stop()
        transport?.close()
        transport = nil
        session = nil
        onEvent?(.closed(error))
    }

    // MARK: - Handshake

    /// The specification has no bound on the handshake, but recommends each side time out waiting
    /// for the next message, so the whole cleartext phase races a deadline.
    private func performHandshakeWithinTimeout() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.performHandshake()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(Self.handshakeTimeout * 1_000_000_000))
                throw SendspinProtocolError.unexpectedMessage("handshake timed out")
            }
            // Whichever finishes first decides: the group cancels and drains the other on exit.
            _ = try await group.next()
            group.cancelAll()
        }
    }

    private func performHandshake() async throws {
        let transport = SendspinWebSocketTransport(url: server.url)
        self.transport = transport
        try await transport.connect()

        // The prologue is the exact bytes of client/init followed by server/init, so both are kept
        // as transmitted rather than re-encoded.
        let clientInitBytes = try SendspinOutgoingMessage
            .clientInit(clientId: identity.clientId, suite: "25519_ChaChaPoly_SHA256")
            .encoded()
        try sendText(clientInitBytes)

        let serverInitBytes = try await receiveText()
        guard case let .serverInit(serverId, version) = try SendspinIncomingMessage.decode(serverInitBytes) else {
            throw SendspinProtocolError.unexpectedMessage("expected server/init")
        }
        guard version == 1 else { throw SendspinProtocolError.unsupportedVersion(version) }
        guard let serverKey = SendspinBase64URL.decode(serverId), serverKey.count == 32 else {
            throw SendspinProtocolError.invalidServerIdentity
        }
        self.serverId = serverId

        var handshake = try SendspinNoiseHandshake(
            identity: identity,
            serverPublicKey: serverKey,
            prologue: clientInitBytes + serverInitBytes
        )

        let firstMessageBytes = try await receiveText()
        guard case let .noiseHandshake(firstMessage) = try SendspinIncomingMessage.decode(firstMessageBytes) else {
            throw SendspinProtocolError.unexpectedMessage("expected noise/handshake")
        }
        let reference = try handshake.readMessage1(firstMessage)
        let psk = selectPsk(for: reference, serverId: serverId)
        let secondMessage = try handshake.writeMessage2(psk: psk)
        let secondMessageBytes = try SendspinOutgoingMessage.noiseHandshake(secondMessage).encoded()
        try sendText(secondMessageBytes)

        session = handshake.makeSession()
        if matchedCategory == "lt" {
            credentials.markRecordUsed(pskId: psk.identifier)
        }
    }

    /// Picks the PSK the server's `psk_id` names, falling back to the Sentinel when the reference
    /// misses — the client may simply have lost the record, and the specification wants the session
    /// to continue so the server can offer re-pairing rather than the socket dying silently.
    private func selectPsk(for reference: SendspinNoiseHandshake.PskReference, serverId: String) -> SendspinPsk {
        switch reference.category {
        case "lt":
            let record = credentials.pairingRecords().first { $0.pskId == reference.identifier }
            // A record bound to a different server is a misbinding, not a miss: keep the Sentinel
            // so the session stays unauthenticated instead of silently trusting the wrong peer.
            if let record, record.serverId == serverId, let psk = record.psk {
                matchedCategory = "lt"
                return psk
            }
        case "pr":
            let pairingPsk = credentials.pairingPsk()
            if pairingPsk.identifier == reference.identifier {
                matchedCategory = "pr"
                return pairingPsk
            }
        default:
            break
        }
        matchedCategory = "sn"
        return .sentinel
    }

    // MARK: - Receiving

    private func receiveLoop() async {
        while !Task.isCancelled, !isClosed {
            do {
                let frame = try await receiveEncrypted()
                let arrival = SendspinMonotonicClock.nowMicroseconds()
                guard let complete = try reassembler.accept(frame: frame) else { continue }
                let binary = SendspinBinaryMessage(id: complete.id, payload: complete.payload)
                try await handle(binary: binary, arrival: arrival)
            } catch {
                guard !isClosed, !Task.isCancelled else { return }
                Current.Log.error("Sendspin connection to \(server.name) failed: \(error)")
                close(reason: nil, error: error)
                return
            }
        }
    }

    private func handle(binary: SendspinBinaryMessage, arrival: Int64) async throws {
        switch binary {
        case let .json(body):
            let message = try SendspinIncomingMessage.decode(body)
            try await handle(message: message, arrival: arrival)
        case let .audio(chunk):
            handle(audio: chunk)
        case let .unhandled(id):
            Current.Log.verbose("Sendspin ignoring binary message \(id)")
        }
    }

    private func handle(message: SendspinIncomingMessage, arrival: Int64) async throws {
        switch message {
        case let .serverHello(name):
            try sendClientHello()
            onEvent?(.connected(serverName: name, serverId: serverId ?? "", trust: trustLevel))
        case let .activate(activation):
            handle(activation: activation)
        case let .time(sample):
            handle(time: sample, arrival: arrival)
        case let .serverState(state):
            handle(serverState: state)
        case let .playerCommand(command):
            try handle(playerCommand: command)
        case let .streamStart(start):
            handle(streamStart: start)
        case let .streamClear(roles):
            if roles == nil || roles?.contains("player") == true {
                renderer.clearBuffers()
            }
        case let .streamEnd(roles):
            if roles == nil || roles?.contains("player") == true {
                renderer.stop()
                streamFormat = nil
                onEvent?(.streamFormat(nil))
            }
        case let .groupUpdate(group):
            if group.isPlaying, let serverId {
                SendspinPreferences.lastPlaybackServerId = serverId
            }
            onEvent?(.group(group))
        case .pairFinalize:
            persistPairingRecord()
        case .unpair:
            if let serverId {
                credentials.removeRecord(serverId: serverId)
                onEvent?(.unpaired(serverId: serverId))
            }
            close(reason: .unpaired)
        case let .pairAbort(reason):
            Current.Log.info("Sendspin pairing aborted by \(server.name): \(reason)")
            pendingLongTermPsk = nil
        case let .unrecognized(type):
            Current.Log.verbose("Sendspin ignoring \(type) from \(server.name)")
        case .serverInit, .noiseHandshake:
            throw SendspinProtocolError.unexpectedMessage("handshake message in transport mode")
        }
    }

    // MARK: - Handshake follow-up

    private func sendClientHello() throws {
        let hello = SendspinClientHello(
            name: configuration.name,
            deviceInfo: SendspinClientHello.DeviceInfo(
                productName: Current.device.systemModel(),
                manufacturer: "Apple",
                softwareVersion: AppConstants.version
            ),
            supportedRoles: [.player, .metadata, .controller],
            playerSupport: SendspinClientHello.PlayerSupport(
                supportedFormats: configuration.supportedFormats,
                bufferCapacity: configuration.bufferCapacity
            ),
            unpairedAccess: SendspinClientHello.UnpairedAccess(enabled: configuration.unpairedAccessEnabled)
        )
        try send(.clientHello(hello))
    }

    private func handle(activation: SendspinActivation) {
        let activities = Set(activation.activities)
        guard isAllowed(activities: activities) else {
            // Enabling unpaired access is what would make this admissible, so say so rather than
            // reporting a blanket authorization failure.
            let wouldBeAdmissible = matchedCategory == "sn"
                && !configuration.unpairedAccessEnabled
                && activities == ["playback"]
            close(reason: wouldBeAdmissible ? .pairingRequired : .unauthorized)
            return
        }

        let isPlaybackCapable = isAllowed(activities: activities.union(["playback"]))
        if let roles = activation.activeRoles {
            activeRoles = Set(roles.compactMap(SendspinRole.init(rawValue:)))
        }
        if !isPlaybackCapable {
            activeRoles = []
        }
        onEvent?(.rolesActivated(activeRoles))

        if activation.isPairing {
            try? handlePairing(activation: activation)
        }

        if !activeRoles.isEmpty {
            try? sendClientState()
        }
    }

    /// Allowed activity sets are decided by which PSK matched during the handshake.
    private func isAllowed(activities: Set<String>) -> Bool {
        switch matchedCategory {
        case "lt":
            return activities.isEmpty || activities == ["playback"]
        case "pr":
            return activities == ["pairing"]
        default:
            if activities.isEmpty || activities == ["pairing"] {
                return true
            }
            return activities == ["playback"] && configuration.unpairedAccessEnabled
        }
    }

    /// Only the Pairing PSK flow is offered: it needs no PAKE round and no code entry, and it is
    /// the one method every client must implement.
    private func handlePairing(activation: SendspinActivation) throws {
        guard activation.pairing?.method == "pairing_psk", matchedCategory == "pr" else {
            try send(.pairAbort(reason: "method_not_supported"))
            return
        }
        renderer.stop()
        streamFormat = nil
        let longTermPsk = SendspinPsk.generate()
        pendingLongTermPsk = longTermPsk
        try send(.pairFinalize(longTermPsk: SendspinBase64URL.encode(longTermPsk.bytes)))
    }

    private func persistPairingRecord() {
        guard let pendingLongTermPsk, let serverId else { return }
        credentials.store(record: SendspinPairingRecord(
            pskBytes: pendingLongTermPsk.bytes,
            serverId: serverId,
            lastUsed: Current.date()
        ))
        self.pendingLongTermPsk = nil
        onEvent?(.paired(serverId: serverId))
    }

    // MARK: - Player role

    private func handle(streamStart: SendspinStreamStart) {
        guard let player = streamStart.player else { return }
        guard player.format.codec == .pcm else {
            // The server picked a codec this client never advertised; there is nothing to play.
            Current.Log.error("Sendspin stream uses unsupported codec \(player.format.codec.rawValue)")
            return
        }
        guard streamFormat != player.format else { return }
        do {
            try renderer.start(format: player.format)
            renderer.setVolume(volume, muted: muted)
            renderer.setOutputDelay(milliseconds: outputDelayMilliseconds)
            renderer.setClock(clockFilter.snapshot)
            streamFormat = player.format
            onEvent?(.streamFormat(player.format))
        } catch {
            Current.Log.error("Sendspin renderer failed to start: \(error)")
            streamFormat = nil
            onEvent?(.streamFormat(nil))
        }
    }

    private func handle(audio chunk: SendspinAudioChunk) {
        guard let format = streamFormat else { return }
        guard let samples = SendspinPCMDecoder.decode(chunk.data, format: format) else { return }
        renderer.enqueue(
            startServerMicroseconds: chunk.serverTimestamp,
            samples: samples,
            channels: format.channels
        )
    }

    private func handle(playerCommand: SendspinPlayerCommand) throws {
        switch playerCommand.command {
        case "volume":
            guard let value = playerCommand.volume else { return }
            volume = min(max(value, 0), 100)
            SendspinPreferences.volume = volume
        case "mute":
            guard let value = playerCommand.mute else { return }
            muted = value
            SendspinPreferences.isMuted = value
        case "set_output_delay":
            guard let value = playerCommand.outputDelayMs else { return }
            outputDelayMilliseconds = min(max(value, 0), 5_000)
            SendspinPreferences.outputDelayMilliseconds = outputDelayMilliseconds
            renderer.setOutputDelay(milliseconds: outputDelayMilliseconds)
            onEvent?(.outputDelay(milliseconds: outputDelayMilliseconds))
            try sendClientState()
            return
        default:
            return
        }
        renderer.setVolume(volume, muted: muted)
        onEvent?(.playerVolume(volume: volume, muted: muted))
        try sendClientState()
    }

    private func handle(serverState: SendspinServerState) {
        switch serverState.metadata {
        case .unchanged:
            break
        case .cleared:
            onEvent?(.metadata(nil))
        case let .updated(metadata):
            onEvent?(.metadata(metadata))
        }

        switch serverState.controller {
        case .unchanged:
            break
        case .cleared:
            onEvent?(.controller(nil))
        case let .updated(state):
            onEvent?(.controller(state))
        }
    }

    // MARK: - Clock synchronisation

    private func startClockSynchronization() {
        timeTask = Task { [weak self] in
            var sent = 0
            while !Task.isCancelled {
                guard let self else { return }
                try? self.send(.clientTime(clientTransmitted: SendspinMonotonicClock.nowMicroseconds()))
                sent += 1
                let interval = sent < Self.timeBurstCount ? Self.timeBurstInterval : Self.timeSteadyInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    private func handle(time sample: SendspinTimeSample, arrival: Int64) {
        let wasConverged = clockFilter.isConverged
        clockFilter.update(
            clientTransmitted: sample.clientTransmitted,
            serverReceived: sample.serverReceived,
            serverTransmitted: sample.serverTransmitted,
            clientReceived: arrival
        )
        renderer.setClock(clockFilter.snapshot)

        guard clockFilter.isConverged, !wasConverged else { return }
        onEvent?(.clockSynchronized)
        try? sendClientState()
    }

    // MARK: - Outbound

    /// Reports the player's state. `available` only turns true once the clock filter has converged:
    /// until then this device cannot place audio on the shared timeline.
    func sendClientState() throws {
        guard session != nil else { return }
        isAvailable = clockFilter.isConverged && !isOutputTakenByOtherApp
        try send(.clientState(available: isAvailable, player: makePlayerState()))
    }

    func setLocalVolume(_ newVolume: Int, muted newMuted: Bool) throws {
        volume = min(max(newVolume, 0), 100)
        muted = newMuted
        SendspinPreferences.volume = volume
        SendspinPreferences.isMuted = newMuted
        renderer.setVolume(volume, muted: newMuted)
        try sendClientState()
    }

    func setOutputDelay(milliseconds: Int) throws {
        outputDelayMilliseconds = min(max(milliseconds, 0), 5_000)
        SendspinPreferences.outputDelayMilliseconds = outputDelayMilliseconds
        renderer.setOutputDelay(milliseconds: outputDelayMilliseconds)
        try sendClientState()
    }

    /// Reports that something outside Sendspin took the audio output, or gave it back. The server
    /// moves an unavailable player out of its group rather than leaving it playing to nothing.
    func setAvailable(_ available: Bool) throws {
        isOutputTakenByOtherApp = !available
        try sendClientState()
    }

    private func makePlayerState() -> SendspinPlayerState? {
        guard activeRoles.contains(.player) else { return nil }
        return SendspinPlayerState(
            volume: volume,
            muted: muted,
            outputDelayMs: outputDelayMilliseconds,
            requiredLeadTimeMs: configuration.requiredLeadTimeMs,
            minBufferMs: configuration.minBufferMs,
            // The device reports its own volume and accepts all three commands the role defines.
            supportedCommands: ["volume", "mute", "set_output_delay"],
            format: nil
        )
    }

    func send(controllerCommand: SendspinControllerCommand) throws {
        guard activeRoles.contains(.controller) else { return }
        try send(.clientCommand(controller: controllerCommand))
    }

    private func send(_ message: SendspinOutgoingMessage) throws {
        guard let transport, let session else { throw SendspinWebSocketTransport.TransportError.closed }
        let body = try message.encoded()
        let ciphertext = try session.encrypt(SendspinBinaryMessage.jsonFrame(body))
        try transport.send(.binary(ciphertext))
    }

    private func sendText(_ body: Data) throws {
        guard let transport, let text = String(data: body, encoding: .utf8) else {
            throw SendspinWebSocketTransport.TransportError.closed
        }
        try transport.send(.text(text))
    }

    private func receiveText() async throws -> Data {
        guard let transport else { throw SendspinWebSocketTransport.TransportError.closed }
        switch try await transport.receive() {
        case let .text(string):
            return Data(string.utf8)
        case .binary:
            throw SendspinProtocolError.unexpectedMessage("binary frame during the cleartext handshake")
        }
    }

    private func receiveEncrypted() async throws -> Data {
        guard let transport, let session else { throw SendspinWebSocketTransport.TransportError.closed }
        switch try await transport.receive() {
        case let .binary(data):
            return try session.decrypt(data)
        case .text:
            throw SendspinProtocolError.unexpectedMessage("cleartext frame after the handshake")
        }
    }

    private func startPing() {
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.pingInterval * 1_000_000_000))
                guard let self else { return }
                try? await self.transport?.ping()
            }
        }
    }
}
