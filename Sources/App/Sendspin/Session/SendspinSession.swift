import CryptoKit
import Foundation
import Shared

/// One server's connection to this player, from the Noise handshake to the end of the stream.
///
/// The server is the Noise initiator and drives everything; this side answers. After the
/// handshake the session waits for the server's first activation, asks its host whether that
/// connection may take the player, and from then on keeps the clock in sync, plays the stream,
/// follows commands and reports state.
actor SendspinSession {
    enum Failure: Error, Equatable {
        case unexpectedMessage(String)
        case serverRejected(String)
        case unsupportedVersion
        case invalidServerID
        case pskNotFound
        case pskBoundToAnotherServer
        case activationRejected
        case notAdmitted
    }

    static let playerRole = "player@v1"
    static let controllerRole = "controller@v1"
    static let metadataRole = "metadata@v1"
    static let supportedRoles = [playerRole, controllerRole, metadataRole]
    /// One sample rate and channel count, so the player never has to change its output mid-stream:
    /// the server resamples instead. PCM needs no decoder, and every server can produce it.
    static let supportedFormats = [
        SendspinAudioFormat(codec: "pcm", channels: 2, sampleRate: 48000, bitDepth: 24),
        SendspinAudioFormat(codec: "pcm", channels: 2, sampleRate: 48000, bitDepth: 16),
    ]
    /// About five seconds of 24-bit stereo at 48 kHz.
    static let bufferCapacity = 1_500_000
    static let requiredLeadTimeMs = 300
    /// Enough to ride out Wi-Fi jitter.
    static let minBufferMs = 150
    static let handshakeTimeout: TimeInterval = 30

    private enum Incoming {
        case message(SendspinServerMessage?)
        case binary(Data)
    }

    nonisolated let id = UUID()

    private let connection: SendspinFrameConnection
    private weak var host: (any SendspinSessionHost)?
    private let credentials: SendspinCredentialStoring
    private let audio: SendspinAudioRendering
    private let deviceInfo: SendspinDeviceInfo?
    private let makeEphemeral: () -> Curve25519.KeyAgreement.PrivateKey
    private let now: () -> Int64
    private let handshakeTimeout: TimeInterval

    private var transport: SendspinNoiseTransport?
    private var reassembler = SendspinFragmentReassembler()
    private(set) var serverID: String?
    private(set) var serverName: String?
    private var category: SendspinPskCategory = .sentinel
    private var activities: [String] = []
    private var activeRoles: [String] = []
    private var isActivated = false
    private(set) var isAdmitted = false
    private var pairingIndex = 0
    private var pendingPairingPsk: SendspinPsk?
    private var timeFilter = SendspinTimeFilter()
    private var isAvailable = true
    private(set) var isStreaming = false
    private var settings: SendspinPlayerSettings
    private var controllerState: SendspinControllerState?
    private var pendingMetadata: Task<Void, Never>?
    private var timeTask: Task<Void, Never>?
    private var isClosed = false
    private var didReportClose = false

    init(
        connection: SendspinFrameConnection,
        host: any SendspinSessionHost,
        credentials: SendspinCredentialStoring,
        audio: SendspinAudioRendering,
        settings: SendspinPlayerSettings,
        deviceInfo: SendspinDeviceInfo?,
        handshakeTimeout: TimeInterval = SendspinSession.handshakeTimeout,
        makeEphemeral: @escaping () -> Curve25519.KeyAgreement.PrivateKey = { Curve25519.KeyAgreement.PrivateKey() },
        now: @escaping () -> Int64 = SendspinClock.nowMicroseconds
    ) {
        self.connection = connection
        self.host = host
        self.credentials = credentials
        self.audio = audio
        self.settings = settings
        self.deviceInfo = deviceInfo
        self.handshakeTimeout = handshakeTimeout
        self.makeEphemeral = makeEphemeral
        self.now = now
    }

    // MARK: - Lifecycle

    /// Runs the connection until either side ends it.
    func run() async {
        let timeout = handshakeTimeout
        // A server that never gets as far as activating the connection is dropped, so a stalled
        // peer cannot hold a socket open forever.
        let watchdog = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.dropIfNotActivated()
        }
        do {
            try await connection.start()
            try await performHandshake()
            try await exchangeHellos()
            watchdog.cancel()
            while !isClosed {
                switch try await receiveEncrypted() {
                case let .message(message?):
                    try await handle(message)
                case .message(nil):
                    continue
                case let .binary(data):
                    handleBinary(data)
                }
            }
        } catch {
            if !isClosed {
                Current.Log.info("Sendspin: connection from \(serverName ?? "a server") ended: \(error)")
            }
        }
        watchdog.cancel()
        close()
        await reportClosed()
    }

    /// Hands the player to a server that outranks this one.
    func displace() {
        closeWithGoodbye(.anotherServer)
    }

    func disconnect(reason: SendspinGoodbyeReason) {
        closeWithGoodbye(reason)
    }

    /// Whether something outside Sendspin, such as a phone call, has the audio hardware.
    func setAvailable(_ available: Bool) {
        guard available != isAvailable else { return }
        isAvailable = available
        if !available, isStreaming {
            audio.clear()
        }
        sendStateIfActive()
    }

    func update(settings newSettings: SendspinPlayerSettings) {
        let previous = settings
        settings = newSettings
        if previous.volume != newSettings.volume || previous.isMuted != newSettings.isMuted {
            audio.setVolume(newSettings.volume, muted: newSettings.isMuted)
        }
        if previous.outputDelayMs != newSettings.outputDelayMs {
            audio.setOutputDelay(milliseconds: newSettings.outputDelayMs)
        }
        if previous.volume != newSettings.volume || previous.isMuted != newSettings.isMuted ||
            previous.outputDelayMs != newSettings.outputDelayMs {
            sendStateIfActive()
        }
    }

    /// Sends a group command, if the server currently accepts it from this device.
    func sendControllerCommand(_ command: SendspinControllerCommand) {
        guard isRoleActive(Self.controllerRole),
              controllerState?.supportedCommands.contains(command.command) == true else { return }
        send(.command(SendspinClientCommand(controller: command)))
    }

    /// Whether the connection is keyed by a pairing record rather than running unpaired.
    var isPaired: Bool {
        category == .longTerm
    }

    var supportedControllerCommands: [String] {
        isRoleActive(Self.controllerRole) ? controllerState?.supportedCommands ?? [] : []
    }

    // MARK: - Handshake

    private func performHandshake() async throws {
        let identity = credentials.identity()
        let clientInit = try SendspinClientMessage.encode(
            type: "client/init",
            payload: SendspinClientInit(clientID: identity.clientID)
        )
        connection.send(text: clientInit)

        let serverInitBytes = try await receiveText()
        let header = try JSONDecoder().decode(SendspinMessageHeader.self, from: serverInitBytes)
        if header.type == "server/error" {
            let reason = try? JSONDecoder().decode(SendspinEnvelope<SendspinServerError>.self, from: serverInitBytes)
            throw Failure.serverRejected(reason?.payload.reason ?? "unknown")
        }
        guard header.type == "server/init" else { throw Failure.unexpectedMessage(header.type) }
        let serverInit = try JSONDecoder().decode(SendspinEnvelope<SendspinServerInit>.self, from: serverInitBytes)
            .payload
        guard serverInit.version == SendspinClientInit.protocolVersion else { throw Failure.unsupportedVersion }
        guard serverInit.serverID.count == 43,
              let serverKey = SendspinBase64URL.decode(serverInit.serverID), serverKey.count == 32 else {
            throw Failure.invalidServerID
        }
        serverID = serverInit.serverID

        var handshake = try SendspinNoiseHandshake(
            identity: identity,
            serverPublicKey: serverKey,
            prologue: clientInit + serverInitBytes,
            ephemeral: makeEphemeral()
        )
        let message1Bytes = try await receiveText()
        let message1 = try JSONDecoder().decode(
            SendspinEnvelope<SendspinNoiseHandshakeMessage>.self,
            from: message1Bytes
        )
        guard message1.type == "noise/handshake" else { throw Failure.unexpectedMessage(message1.type) }
        let (message2, newTransport) = try respond(
            to: message1.payload,
            with: &handshake,
            serverID: serverInit.serverID,
            allowsSentinelFallback: true
        )
        let reply = try SendspinClientMessage.handshake(message2).encoded()
        connection.send(text: reply)
        transport = newTransport
    }

    /// Reads Noise message 1, picks the PSK it names and writes message 2.
    private func respond(
        to message: SendspinNoiseHandshakeMessage,
        with handshake: inout SendspinNoiseHandshake,
        serverID: String,
        allowsSentinelFallback: Bool
    ) throws -> (SendspinNoiseHandshakeMessage, SendspinNoiseTransport) {
        guard let bytes = SendspinBase64URL.decode(message.data) else { throw SendspinNoiseError.messageTooShort }
        let payload = try handshake.readMessage1(bytes)
        guard let reference = try? JSONDecoder().decode(SendspinPskReference.self, from: payload) else {
            throw SendspinNoiseError.malformedHandshakePayload
        }
        let (psk, matchedCategory) = try resolve(
            reference,
            serverID: serverID,
            allowsSentinelFallback: allowsSentinelFallback
        )
        let (reply, transport) = try handshake.writeMessage2(psk: psk)
        category = matchedCategory
        pairingIndex = 0
        if matchedCategory == .longTerm {
            credentials.markPairingRecordUsed(serverID: serverID, at: Date())
        }
        return (SendspinNoiseHandshakeMessage(data: SendspinBase64URL.encode(reply)), transport)
    }

    private func resolve(
        _ reference: SendspinPskReference,
        serverID: String,
        allowsSentinelFallback: Bool
    ) throws -> (SendspinPsk, SendspinPskCategory) {
        switch reference.category {
        case .sentinel where reference.pskID == SendspinPsk.sentinel.identifier:
            return (.sentinel, .sentinel)
        case .pairing where reference.pskID == credentials.pairingPsk().identifier:
            return (credentials.pairingPsk(), .pairing)
        case .longTerm:
            if let record = credentials.pairingRecord(pskID: reference.pskID), let psk = record.pskValue {
                // A record matched by its PSK must belong to the server actually connected.
                guard record.serverID == serverID else { throw Failure.pskBoundToAnotherServer }
                return (psk, .longTerm)
            }
        default:
            break
        }
        // The server referenced a credential this device no longer has: answer unpaired so the
        // connection can carry a re-pairing instead of failing outright.
        guard allowsSentinelFallback else { throw Failure.pskNotFound }
        Current.Log.warning("Sendspin: \(serverID) referenced an unknown credential, continuing unpaired")
        return (.sentinel, .sentinel)
    }

    private func rehandshake(_ message: SendspinNoiseHandshakeMessage) throws {
        guard let transport, let serverID, let serverKey = SendspinBase64URL.decode(serverID) else {
            throw Failure.unexpectedMessage("noise/handshake")
        }
        var handshake = try SendspinNoiseHandshake(
            identity: credentials.identity(),
            serverPublicKey: serverKey,
            prologue: transport.handshakeHash,
            ephemeral: makeEphemeral()
        )
        let (reply, newTransport) = try respond(
            to: message,
            with: &handshake,
            serverID: serverID,
            allowsSentinelFallback: false
        )
        // Message 2 still travels under the old keys; everything after it uses the new ones.
        send(.handshake(reply))
        self.transport = newTransport
    }

    // MARK: - Hello and activation

    private func exchangeHellos() async throws {
        guard case let .message(.hello(hello)?) = try await receiveEncrypted() else {
            throw Failure.unexpectedMessage("expected server/hello")
        }
        serverName = hello.name
        send(.hello(makeHello()))

        guard case let .message(.activate(activation)?) = try await receiveEncrypted() else {
            throw Failure.unexpectedMessage("expected server/activate")
        }
        let decision = evaluate(activation)
        if case let .goodbye(reason) = decision {
            closeWithGoodbye(reason)
            throw Failure.activationRejected
        }
        isActivated = true

        let candidate = SendspinAdmissionCandidate(serverID: serverID ?? "", activities: activation.activities)
        guard let host, await host.admit(self, candidate: candidate) else {
            if activation.activities.contains(SendspinActivity.pairing.rawValue) {
                send(.pairAbort(SendspinPairAbort(reason: "concurrent_attempt")))
                close()
            } else {
                closeWithGoodbye(.concurrentAttempt)
            }
            throw Failure.notAdmitted
        }
        isAdmitted = true
        await report(.connected(serverName: hello.name))
        audio.setVolume(settings.volume, muted: settings.isMuted)
        audio.setOutputDelay(milliseconds: settings.outputDelayMs)
        startTimeSync()
        await apply(activation, decision: decision, isInitial: true)
    }

    private func makeHello() -> SendspinClientHello {
        SendspinClientHello(
            name: settings.name,
            deviceInfo: deviceInfo,
            supportedRoles: Self.supportedRoles,
            playerSupport: SendspinPlayerSupport(
                supportedFormats: Self.supportedFormats,
                bufferCapacity: Self.bufferCapacity
            ),
            supportedPairMethods: SendspinSupportedPairMethods(
                pairingPsk: SendspinPairMethodDescriptor(locations: ["device"])
            ),
            unpairedAccess: SendspinUnpairedAccess(enabled: settings.allowsUnpairedAccess)
        )
    }

    /// The roles an activation leaves active: an omitted list keeps the previous one, unless the
    /// connection can no longer carry roles at all.
    private func effectiveRoles(for activation: SendspinServerActivate) -> [String] {
        if let roles = activation.activeRoles {
            return roles
        }
        let declared = Set(activation.activities.compactMap(SendspinActivity.init(rawValue:)))
        return SendspinActivationPolicy.isPlaybackCapable(
            declared,
            category: category,
            unpairedAccess: settings.allowsUnpairedAccess
        ) ? activeRoles : []
    }

    private func evaluate(_ activation: SendspinServerActivate) -> SendspinActivationDecision {
        SendspinActivationPolicy.evaluate(
            activities: activation.activities,
            hasRoles: !effectiveRoles(for: activation).isEmpty,
            pairing: activation.pairing,
            category: category,
            unpairedAccess: settings.allowsUnpairedAccess
        )
    }

    private func apply(
        _ activation: SendspinServerActivate,
        decision: SendspinActivationDecision,
        isInitial: Bool
    ) async {
        let roles = effectiveRoles(for: activation)
        let removed = Set(activeRoles).subtracting(roles)
        let added = Set(roles).subtracting(activeRoles)
        activities = activation.activities
        activeRoles = roles

        if removed.contains(Self.playerRole) {
            stopStream()
        }
        if removed.contains(Self.metadataRole) {
            pendingMetadata?.cancel()
            await report(.metadata(nil, positionMs: nil))
        }
        if removed.contains(Self.controllerRole) {
            controllerState = nil
            await report(.controller(nil))
        }
        if activities.contains(SendspinActivity.playback.rawValue), let serverID {
            credentials.lastPlaybackServerID = serverID
        }
        // The initial state goes out with the first activation that has roles, and again whenever
        // the player role is (re)added, as the specification requires.
        if isInitial ? !roles.isEmpty : added.contains(Self.playerRole) {
            sendState()
        }

        if activities.contains(SendspinActivity.pairing.rawValue) {
            pairingIndex += 1
            if decision == .pairAbortMethodNotSupported {
                send(.pairAbort(SendspinPairAbort(reason: "method_not_supported")))
            } else {
                startPairing()
            }
        } else {
            pendingPairingPsk = nil
        }
    }

    /// The Pairing PSK flow: the session is already authenticated by the pairing PSK, so the new
    /// long-term PSK goes straight out, and the record is kept once the server confirms it kept
    /// its own.
    private func startPairing() {
        let psk = SendspinPsk.generate()
        pendingPairingPsk = psk
        send(.pairInit(SendspinPairInit(pairingIndex: pairingIndex)))
        send(.pairFinalize(SendspinPairFinalize(longTermPsk: SendspinBase64URL.encode(psk.bytes))))
    }

    // MARK: - Messages

    private func handle(_ message: SendspinServerMessage) async throws {
        switch message {
        case .hello:
            break
        case let .activate(activation):
            let decision = evaluate(activation)
            if case let .goodbye(reason) = decision {
                closeWithGoodbye(reason)
                return
            }
            await apply(activation, decision: decision, isInitial: false)
        case let .time(sample):
            handleTime(sample)
        case let .state(state):
            await handleState(state)
        case let .command(command):
            await handleCommand(command)
        case let .streamStart(start):
            await startStream(start)
        case let .streamClear(roles):
            if roles.includes("player"), isStreaming {
                audio.clear()
            }
        case let .streamEnd(roles):
            if roles.includes("player"), isStreaming {
                stopStream()
                await report(.streamEnded)
            }
        case let .groupUpdate(update):
            await report(.groupUpdated(update))
        case .unpair:
            // Only a paired session has a record of its own to drop.
            guard category == .longTerm, let serverID else { return }
            credentials.removePairingRecord(serverID: serverID)
            await report(.unpaired)
            closeWithGoodbye(.unpaired)
        case .pairFinalize:
            guard let psk = pendingPairingPsk, let serverID else { return }
            pendingPairingPsk = nil
            credentials.storePairingRecord(SendspinPairingRecord(
                serverID: serverID,
                serverName: serverName ?? serverID,
                psk: SendspinBase64URL.encode(psk.bytes),
                lastUsed: Date()
            ))
            await report(.paired(serverName: serverName ?? serverID))
        case .pairAbort:
            pendingPairingPsk = nil
        case let .handshake(handshake):
            try rehandshake(handshake)
        }
    }

    private func handleTime(_ sample: SendspinServerTime) {
        let wasSynchronized = timeFilter.isSynchronized
        timeFilter.update(sample: sample, receivedAt: lastReceivedAt)
        audio.update(mapping: timeFilter.mapping)
        if !wasSynchronized, timeFilter.isSynchronized {
            sendStateIfActive()
        }
    }

    private func handleState(_ state: SendspinServerState) async {
        if let controller = state.controller, isRoleActive(Self.controllerRole) {
            controllerState = controller
            await report(.controller(controller))
        }
        guard let metadata = state.metadata, isRoleActive(Self.metadataRole) else { return }
        pendingMetadata?.cancel()
        pendingMetadata = nil
        let delay = timeFilter.mapping.clientTime(fromServer: metadata.timestamp) - now()
        guard delay > 0 else {
            await reportMetadata(metadata)
            return
        }
        // A future timestamp schedules the update for when that audio is heard, typically the
        // next track's details timed to the track change.
        pendingMetadata = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1000)
            guard !Task.isCancelled else { return }
            await self?.reportMetadata(metadata)
        }
    }

    private func reportMetadata(_ metadata: SendspinMetadataState) async {
        let serverNow = timeFilter.mapping.serverTime(fromClient: now())
        await report(.metadata(metadata, positionMs: metadata.trackPosition(atServerTime: serverNow)))
    }

    private func handleCommand(_ command: SendspinServerCommand) async {
        guard let player = command.player, isRoleActive(Self.playerRole) else { return }
        switch player.command {
        case "volume":
            guard let volume = player.volume else { return }
            settings.volume = min(max(volume, 0), 100)
        case "mute":
            guard let mute = player.mute else { return }
            settings.isMuted = mute
        case "set_output_delay":
            guard let delay = player.outputDelayMs else { return }
            settings.outputDelayMs = min(max(delay, 0), 5000)
            audio.setOutputDelay(milliseconds: settings.outputDelayMs)
            sendState()
            await report(.outputDelayChanged(milliseconds: settings.outputDelayMs))
            return
        default:
            return
        }
        audio.setVolume(settings.volume, muted: settings.isMuted)
        sendState()
        await report(.volumeChanged(volume: settings.volume, muted: settings.isMuted))
    }

    private func startStream(_ start: SendspinStreamStart) async {
        guard let format = start.player, isRoleActive(Self.playerRole) else { return }
        do {
            try audio.start(format: format)
            audio.update(mapping: timeFilter.mapping)
            let wasStreaming = isStreaming
            isStreaming = true
            if !wasStreaming {
                await report(.streamStarted)
            }
        } catch {
            Current.Log.error("Sendspin: could not start audio output: \(error)")
        }
    }

    private func stopStream() {
        guard isStreaming else { return }
        isStreaming = false
        audio.stop()
    }

    private func handleBinary(_ data: Data) {
        guard data.first == SendspinBinaryType.audioChunk, isStreaming, isAvailable,
              let chunk = SendspinAudioChunk(message: data) else { return }
        audio.enqueue(chunk)
    }

    // MARK: - State

    private func isRoleActive(_ role: String) -> Bool {
        activeRoles.contains(role)
    }

    private func sendStateIfActive() {
        guard isAdmitted, !activeRoles.isEmpty else { return }
        sendState()
    }

    private func sendState() {
        let isPlayer = isRoleActive(Self.playerRole)
        let player = isPlayer ? SendspinPlayerStateReport(
            volume: settings.volume,
            muted: settings.isMuted,
            outputDelayMs: settings.outputDelayMs,
            requiredLeadTimeMs: Self.requiredLeadTimeMs,
            minBufferMs: Self.minBufferMs,
            supportedCommands: SendspinPlayerStateReport.supportedCommands
        ) : nil
        // A player is only available once its clock can place audio on the server's timeline.
        let available = isAvailable && (!isPlayer || timeFilter.isSynchronized)
        send(.state(SendspinClientState(available: available, player: player)))
    }

    private func startTimeSync() {
        timeTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let interval = await self?.sendTimeRequest() else { return }
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    private func sendTimeRequest() -> TimeInterval? {
        guard !isClosed else { return nil }
        send(.time(SendspinClientTime(clientTransmitted: now())))
        return timeFilter.nextSampleInterval
    }

    // MARK: - Wire

    private var lastReceivedAt: Int64 = 0

    private func receiveText() async throws -> Data {
        let frame = try await connection.receive()
        guard frame.kind == .text else { throw Failure.unexpectedMessage("binary message during handshake") }
        return frame.data
    }

    private func receiveEncrypted() async throws -> Incoming {
        while true {
            let frame = try await connection.receive()
            // Anything in the clear once the transport is up is a silent failure.
            guard frame.kind == .binary, transport != nil else {
                throw Failure.unexpectedMessage("cleartext message after the handshake")
            }
            guard let plaintext = try transport?.decrypt(frame.data), !plaintext.isEmpty else {
                throw SendspinNoiseError.messageTooShort
            }
            guard let message = try reassembler.receive(plaintext) else { continue }
            lastReceivedAt = frame.receivedAt
            if message.first == SendspinBinaryType.json {
                let decoded = try SendspinServerMessage.decode(message.dropFirst())
                return .message(decoded)
            }
            return .binary(message)
        }
    }

    private func send(_ message: SendspinClientMessage) {
        guard !isClosed else { return }
        do {
            let body = try message.encoded()
            var plaintext = Data([SendspinBinaryType.json])
            plaintext.append(body)
            for piece in SendspinFragmentation.plaintexts(for: plaintext) {
                guard let ciphertext = try transport?.encrypt(piece) else { return }
                connection.send(binary: ciphertext)
            }
        } catch {
            Current.Log.error("Sendspin: failed to send \(message.type): \(error)")
        }
    }

    private func closeWithGoodbye(_ reason: SendspinGoodbyeReason) {
        send(.goodbye(SendspinClientGoodbye(reason: reason)))
        close()
    }

    private func close() {
        guard !isClosed else { return }
        isClosed = true
        timeTask?.cancel()
        pendingMetadata?.cancel()
        if isAdmitted {
            stopStream()
        }
        connection.close()
    }

    private func dropIfNotActivated() {
        guard !isActivated else { return }
        Current.Log.info("Sendspin: dropping a connection that did not finish setting up in time")
        close()
    }

    private func report(_ event: SendspinSessionEvent) async {
        await host?.session(self, didReport: event)
    }

    private func reportClosed() async {
        guard !didReportClose else { return }
        didReportClose = true
        await host?.sessionDidClose(self)
    }
}
