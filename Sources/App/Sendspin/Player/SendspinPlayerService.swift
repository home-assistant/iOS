import Foundation
import Network
import Shared

/// Owns the listener and every server connection, and decides which one holds the player.
actor SendspinPlayerService: SendspinSessionHost {
    private enum Constants {
        /// Servers reconnect on their own, so a handful covers one retrying while an old socket
        /// has not been noticed dead yet; the cap keeps a misbehaving peer from exhausting sockets.
        static let maximumConnections = 6
    }

    private struct Accepted {
        let session: SendspinSession
        let sequence: Int
    }

    private let credentials: SendspinCredentialStoring
    private let audio: SendspinAudioRendering
    private let deviceInfo: SendspinDeviceInfo?
    private let advertises: Bool
    private let queue = DispatchQueue(label: "io.home-assistant.sendspin", qos: .userInitiated)
    private let onStatus: @Sendable (SendspinPlayerStatus) -> Void
    private let onEvent: @Sendable (SendspinSessionEvent) -> Void

    private var settings: SendspinPlayerSettings
    private var listener: SendspinListener?
    private var listeningPort: UInt16?
    private var sessions: [UUID: Accepted] = [:]
    private var nextSequence = 0
    private var admitted: SendspinSession?
    private var admittedCandidate: SendspinAdmissionCandidate?
    private var admittedServerName: String?
    private var isAvailable = true

    init(
        credentials: SendspinCredentialStoring,
        audio: SendspinAudioRendering,
        settings: SendspinPlayerSettings,
        deviceInfo: SendspinDeviceInfo?,
        advertises: Bool = true,
        onStatus: @escaping @Sendable (SendspinPlayerStatus) -> Void,
        onEvent: @escaping @Sendable (SendspinSessionEvent) -> Void
    ) {
        self.credentials = credentials
        self.audio = audio
        self.settings = settings
        self.deviceInfo = deviceInfo
        self.advertises = advertises
        self.onStatus = onStatus
        self.onEvent = onEvent
    }

    // MARK: - Listener

    func start(port: UInt16) {
        stopListening()
        onStatus(.starting)
        do {
            listener = try SendspinListener(
                port: port,
                advertisedName: advertises ? settings.name : nil,
                queue: queue
            ) { [weak self] event in
                Task { await self?.listener(event) }
            }
        } catch {
            Current.Log.error("Sendspin: failed to open port \(port): \(error)")
            onStatus(.failed(message: error.localizedDescription))
        }
    }

    /// Closes every connection, telling each server why, and stops advertising.
    func stop(reason: SendspinGoodbyeReason) async {
        stopListening()
        for accepted in sessions.values {
            await accepted.session.disconnect(reason: reason)
        }
        sessions.removeAll()
        admitted = nil
        admittedCandidate = nil
        onStatus(.stopped)
    }

    private func stopListening() {
        listener?.cancel()
        listener = nil
        listeningPort = nil
    }

    private func listener(_ event: SendspinListener.Event) {
        switch event {
        case let .ready(port):
            listeningPort = port
            publishStatus()
        case let .failed(error):
            Current.Log.error("Sendspin listener failed: \(error)")
            stopListening()
            onStatus(.failed(message: error.localizedDescription))
        case .cancelled:
            break
        case let .connection(connection):
            accept(connection)
        }
    }

    private func accept(_ connection: NWConnection) {
        guard listener != nil else {
            connection.cancel()
            return
        }
        // Room is made for the newcomer by dropping the connection that has waited longest
        // without being admitted: the newest is the one a server is actively setting up.
        while sessions.count >= Constants.maximumConnections,
              let oldest = sessions.values.filter({ $0.session !== admitted }).min(by: { $0.sequence < $1.sequence }) {
            sessions[oldest.session.id] = nil
            Task { await oldest.session.disconnect(reason: .concurrentAttempt) }
        }

        let session = SendspinSession(
            connection: SendspinWebSocket(connection: connection, queue: queue),
            host: self,
            credentials: credentials,
            audio: audio,
            settings: settings,
            deviceInfo: deviceInfo
        )
        nextSequence += 1
        sessions[session.id] = Accepted(session: session, sequence: nextSequence)
        Task { await session.run() }
    }

    // MARK: - Settings and commands

    func update(settings newSettings: SendspinPlayerSettings) async {
        let previous = settings
        settings = newSettings
        for accepted in sessions.values {
            await accepted.session.update(settings: newSettings)
        }
        let renamed = previous.name != newSettings.name
        guard renamed || previous.allowsUnpairedAccess != newSettings.allowsUnpairedAccess else { return }
        // The name and the unpaired access setting only travel in the hello, so the connections
        // that depend on them are closed for their servers to reconnect. Turning unpaired access
        // off ends the unpaired ones for good, as the specification requires.
        for accepted in sessions.values {
            if !renamed, await accepted.session.isPaired {
                continue
            }
            await accepted.session.disconnect(
                reason: renamed || newSettings.allowsUnpairedAccess ? .restart : .pairingRequired
            )
        }
        if renamed, let port = listeningPort {
            start(port: port)
        }
    }

    func sendControllerCommand(_ command: SendspinControllerCommand) async {
        await admitted?.sendControllerCommand(command)
    }

    func setAvailable(_ available: Bool) async {
        isAvailable = available
        await admitted?.setAvailable(available)
    }

    var isStreaming: Bool {
        get async { await admitted?.isStreaming ?? false }
    }

    // MARK: - SendspinSessionHost

    func admit(_ session: SendspinSession, candidate: SendspinAdmissionCandidate) async -> Bool {
        guard sessions[session.id] != nil else { return false }
        if let admitted, admitted !== session {
            guard SendspinAdmissionPolicy.admits(
                candidate,
                over: admittedCandidate,
                lastPlaybackServerID: credentials.lastPlaybackServerID
            ) else { return false }
            await admitted.displace()
        }
        admitted = session
        admittedCandidate = candidate
        if !isAvailable {
            await session.setAvailable(false)
        }
        return true
    }

    func session(_ session: SendspinSession, didReport event: SendspinSessionEvent) async {
        guard session === admitted else { return }
        switch event {
        case let .connected(serverName):
            admittedServerName = serverName
            publishStatus()
        case .streamStarted:
            onStatus(.playing(serverName: admittedServerName ?? ""))
        case .streamEnded:
            publishStatus()
        case let .volumeChanged(volume, muted):
            settings.volume = volume
            settings.isMuted = muted
        case let .outputDelayChanged(milliseconds):
            settings.outputDelayMs = milliseconds
        default:
            break
        }
        onEvent(event)
    }

    func sessionDidClose(_ session: SendspinSession) async {
        sessions[session.id] = nil
        guard session === admitted else { return }
        admitted = nil
        admittedCandidate = nil
        admittedServerName = nil
        onEvent(.metadata(nil, positionMs: nil))
        onEvent(.controller(nil))
        onEvent(.streamEnded)
        publishStatus()
    }

    private func publishStatus() {
        if let admittedServerName {
            onStatus(.connected(serverName: admittedServerName))
        } else if let listeningPort {
            onStatus(.listening(port: listeningPort))
        }
    }
}
