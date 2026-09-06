import AVFoundation
import Combine
import Foundation
import Shared

/// Turns the companion app into a Sendspin player: it finds servers on the local network, keeps one
/// session open, and drives the audio engine, the lock screen and the settings screen from it.
///
/// The player is opt-in and off until the user switches it on, because it holds an audio session and
/// a socket for as long as it runs.
@MainActor
final class SendspinPlayerManager: ObservableObject {
    static let shared = SendspinPlayerManager()

    /// The Sendspin protocol is still experimental and its specification can still change, so the
    /// player ships to beta testers while it settles.
    static var isAvailable: Bool { Current.isTestFlight }

    private static let reconnectDelays: [TimeInterval] = [2, 5, 10, 20, 30]
    private static let statisticsInterval: TimeInterval = 1

    @Published private(set) var status: SendspinPlayerStatus = .off
    @Published private(set) var servers: [SendspinDiscoveredServer] = []
    @Published private(set) var metadata: SendspinTrackMetadata?
    @Published private(set) var controllerState: SendspinControllerState?
    @Published private(set) var group: SendspinGroupState?
    @Published private(set) var streamFormat: SendspinAudioFormat?
    @Published private(set) var statistics: SendspinRendererStatistics = .empty
    @Published private(set) var volume: Int = SendspinPreferences.volume
    @Published private(set) var isMuted: Bool = SendspinPreferences.isMuted
    @Published private(set) var outputDelayMilliseconds: Int = SendspinPreferences.outputDelayMilliseconds
    @Published private(set) var pairedServerIds: [String] = []

    var isEnabled: Bool { SendspinPreferences.isEnabled }

    /// The token an operator enters into their server to pair with this device. It carries the
    /// pairing PSK, so it is only ever shown behind an explicit tap in settings.
    var pairingToken: SendspinPairingToken {
        SendspinPairingToken(clientKey: identity.publicKeyBytes, pairingPsk: credentials.pairingPsk())
    }

    var clientId: String { identity.clientId }

    private let credentials = SendspinCredentialsStore()
    private let renderer = SendspinAudioRenderer()
    private let browser = SendspinServerBrowser()
    private let nowPlaying = SendspinNowPlayingController()
    private lazy var identity: SendspinIdentity = credentials.identity()

    private var connection: SendspinConnection?
    private var reconnectTask: Task<Void, Never>?
    private var statisticsTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var observers: [NSObjectProtocol] = []
    private var isSessionActive = false
    private var wasInterrupted = false

    private init() {}

    // MARK: - Lifecycle

    /// Installs the audio observers and starts the player if the user has already switched it on.
    /// Called once at launch; cheap when the feature is off.
    func start() {
        guard Self.isAvailable, observers.isEmpty else { return }
        installAudioObservers()
        nowPlaying.onCommand = { [weak self] command in
            self?.send(command)
        }
        guard SendspinPreferences.isEnabled else { return }
        beginSearching()
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != SendspinPreferences.isEnabled else { return }
        SendspinPreferences.isEnabled = enabled
        if enabled {
            beginSearching()
        } else {
            teardown(reason: .userRequest)
        }
        objectWillChange.send()
    }

    /// Pins the player to one server, or clears the pin so it takes whatever it finds.
    func selectServer(_ server: SendspinDiscoveredServer?) {
        SendspinPreferences.selectedServerName = server?.id
        disconnect(reason: .anotherServer)
        connectIfPossible()
    }

    var selectedServerName: String? { SendspinPreferences.selectedServerName }

    // MARK: - Player controls

    func setVolume(_ newVolume: Int) {
        volume = min(max(newVolume, 0), 100)
        SendspinPreferences.volume = volume
        renderer.setVolume(volume, muted: isMuted)
        try? connection?.setLocalVolume(volume, muted: isMuted)
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        SendspinPreferences.isMuted = muted
        renderer.setVolume(volume, muted: muted)
        try? connection?.setLocalVolume(volume, muted: muted)
    }

    func setOutputDelay(milliseconds: Int) {
        outputDelayMilliseconds = min(max(milliseconds, 0), 5_000)
        SendspinPreferences.outputDelayMilliseconds = outputDelayMilliseconds
        renderer.setOutputDelay(milliseconds: outputDelayMilliseconds)
        try? connection?.setOutputDelay(milliseconds: outputDelayMilliseconds)
    }

    func send(_ command: SendspinControllerCommand) {
        try? connection?.send(controllerCommand: command)
    }

    /// Drops every pairing and rotates the identity, so servers see a brand new device.
    func forgetPairings() {
        teardown(reason: .unpaired)
        credentials.reset()
        identity = credentials.identity()
        pairedServerIds = []
        if SendspinPreferences.isEnabled {
            beginSearching()
        }
    }

    // MARK: - Discovery and connection

    private func beginSearching() {
        status = .searching
        pairedServerIds = credentials.pairingRecords().map(\.serverId)
        browser.onChange = { [weak self] servers in
            // Bonjour callbacks land on the main run loop already; the hop just makes the
            // isolation explicit rather than assumed.
            Task { @MainActor in
                guard let self else { return }
                self.servers = servers
                connectIfPossible()
            }
        }
        browser.start()
        startStatisticsUpdates()
    }

    private func connectIfPossible() {
        guard SendspinPreferences.isEnabled, connection == nil, reconnectTask == nil else { return }
        guard let server = preferredServer() else { return }
        let connection = SendspinConnection(
            server: server,
            identity: identity,
            credentials: credentials,
            renderer: renderer,
            configuration: .current(name: SendspinPreferences.playerName)
        )
        connection.onEvent = { [weak self, weak connection] event in
            guard let connection else { return }
            self?.handle(event: event, from: connection)
        }
        self.connection = connection
        status = .connecting(serverName: server.name)
        activateAudioSession()
        Task { await connection.start() }
    }

    /// The server the user pinned, or the first one discovered when nothing is pinned.
    private func preferredServer() -> SendspinDiscoveredServer? {
        if let selected = SendspinPreferences.selectedServerName {
            return servers.first { $0.id == selected }
        }
        return servers.first
    }

    private func handle(event: SendspinConnectionEvent, from connection: SendspinConnection) {
        guard connection === self.connection else { return }
        switch event {
        case let .connected(serverName, _, trust):
            reconnectAttempt = 0
            status = .connected(serverName: serverName, trust: trust, isReady: connection.isClockSynchronized)
            pairedServerIds = credentials.pairingRecords().map(\.serverId)
        case .rolesActivated:
            break
        case .clockSynchronized:
            if case let .connected(name, trust, _) = status {
                status = .connected(serverName: name, trust: trust, isReady: true)
            }
        case let .metadata(metadata):
            self.metadata = metadata
            updateNowPlaying()
        case let .controller(state):
            controllerState = state
            updateNowPlaying()
        case let .group(group):
            self.group = group
            updateNowPlaying()
        case let .playerVolume(volume, muted):
            self.volume = volume
            isMuted = muted
        case let .outputDelay(milliseconds):
            outputDelayMilliseconds = milliseconds
        case let .streamFormat(format):
            streamFormat = format
            if format == nil {
                nowPlaying.clear()
            } else {
                activateAudioSession()
            }
        case .paired:
            pairedServerIds = credentials.pairingRecords().map(\.serverId)
        case let .unpaired(serverId):
            pairedServerIds.removeAll { $0 == serverId }
        case let .closed(error):
            self.connection = nil
            metadata = nil
            controllerState = nil
            group = nil
            streamFormat = nil
            nowPlaying.clear()
            deactivateAudioSession()
            if let error {
                status = .failed(error.localizedDescription)
            }
            scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        guard SendspinPreferences.isEnabled, reconnectTask == nil else { return }
        let delay = Self.reconnectDelays[min(reconnectAttempt, Self.reconnectDelays.count - 1)]
        reconnectAttempt += 1
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            reconnectTask = nil
            if case .failed = status {
                // Leave the failure on screen; the attempt below replaces it either way.
            } else {
                status = .searching
            }
            connectIfPossible()
        }
    }

    private func disconnect(reason: SendspinGoodbyeReason) {
        reconnectTask?.cancel()
        reconnectTask = nil
        let connection = self.connection
        self.connection = nil
        connection?.close(reason: reason)
    }

    private func teardown(reason: SendspinGoodbyeReason) {
        disconnect(reason: reason)
        browser.stop()
        browser.onChange = nil
        statisticsTask?.cancel()
        statisticsTask = nil
        servers = []
        metadata = nil
        controllerState = nil
        group = nil
        streamFormat = nil
        statistics = .empty
        nowPlaying.clear()
        deactivateAudioSession()
        status = .off
    }

    // MARK: - Now playing

    private func updateNowPlaying() {
        let position: Int? = {
            guard let metadata, let serverTime = connection?.currentServerTimeMicroseconds else { return nil }
            return metadata.positionMilliseconds(atServerTime: serverTime)
        }()
        nowPlaying.update(
            metadata: metadata,
            positionMilliseconds: position,
            isPlaying: group?.isPlaying ?? false,
            controller: controllerState
        )
    }

    private func startStatisticsUpdates() {
        guard statisticsTask == nil else { return }
        statisticsTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.statisticsInterval * 1_000_000_000))
                guard let self else { return }
                statistics = renderer.statistics(sampleRate: streamFormat?.sampleRate ?? 0)
            }
        }
    }

    // MARK: - Audio session

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            if let sampleRate = streamFormat?.sampleRate {
                try? session.setPreferredSampleRate(Double(sampleRate))
            }
            try session.setActive(true)
            isSessionActive = true
            renderer.setOutputLatency(seconds: session.outputLatency)
        } catch {
            Current.Log.error("Sendspin could not activate the audio session: \(error)")
        }
    }

    private func deactivateAudioSession() {
        guard isSessionActive else { return }
        isSessionActive = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func installAudioObservers() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in self?.handleInterruption(notification) }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleRouteChange() }
        })
        observers.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleRouteChange() }
        })
    }

    /// An interruption takes the output away entirely, so the server is told this player is
    /// unavailable and moved out of its group rather than left playing to nothing.
    private func handleInterruption(_ notification: Notification) {
        guard
            let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else {
            return
        }

        switch type {
        case .began:
            wasInterrupted = true
            renderer.clearBuffers()
            try? connection?.setAvailable(false)
        case .ended:
            guard wasInterrupted else { return }
            wasInterrupted = false
            activateAudioSession()
            try? renderer.resume()
            try? connection?.setAvailable(true)
        @unknown default:
            break
        }
    }

    private func handleRouteChange() {
        let session = AVAudioSession.sharedInstance()
        renderer.setOutputLatency(seconds: session.outputLatency)
        // The engine stops itself when the hardware format changes; buffered audio is stale by then.
        renderer.clearBuffers()
        try? renderer.resume()
    }
}
