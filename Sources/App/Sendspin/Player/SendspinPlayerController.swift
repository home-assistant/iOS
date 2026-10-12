import Foundation
import Shared
import UIKit

/// Owns the Sendspin player for the app: it runs while the user has it switched on and the app is
/// in front, and keeps running in the background for as long as audio is playing.
///
/// iOS suspends the app shortly after it leaves the screen unless it is playing audio, and the
/// socket dies with it, so an idle player is stopped deliberately on the way out rather than left
/// advertising a service nobody answers.
@MainActor
final class SendspinPlayerController: ObservableObject {
    static let shared = SendspinPlayerController()

    @Published private(set) var status: SendspinPlayerStatus = .stopped
    @Published private(set) var configuration: SendspinPlayerConfiguration
    @Published private(set) var pairedServers: [SendspinPairingRecord] = []
    @Published private(set) var groupName: String?
    @Published private(set) var nowPlaying: SendspinMetadataState?

    private enum Constants {
        static let firstRetryDelay: TimeInterval = 5
        static let maximumRetryDelay: TimeInterval = 300
    }

    let credentials: SendspinCredentialStoring
    private let audio: SendspinAudioOutput
    private lazy var nowPlayingCenter = SendspinNowPlaying { [weak self] command in
        self?.send(command)
    }

    private var service: SendspinPlayerService?
    private var isForeground = true
    private var isStreaming = false
    /// Which service the status reports belong to, so one winding down cannot overwrite the state
    /// of the one that replaced it.
    private var generation = 0
    private var retry: Task<Void, Never>?
    private var retryDelay = Constants.firstRetryDelay

    init(
        credentials: SendspinCredentialStoring = SendspinKeychainCredentialStore(),
        configuration: SendspinPlayerConfiguration? = nil
    ) {
        self.credentials = credentials
        self.configuration = configuration ?? .config
        self.audio = SendspinAudioOutput()
        audio.onInterruption = { [weak self] began in
            Task { @MainActor in await self?.service?.setAvailable(!began) }
        }
    }

    /// The token Music Assistant takes to pair with this player.
    var pairingToken: SendspinPairingToken {
        SendspinPairingToken(clientKey: credentials.identity().publicKeyBytes, pairingPsk: credentials.pairingPsk())
    }

    // MARK: - Configuration and lifecycle

    func applyConfiguration(_ configuration: SendspinPlayerConfiguration = .config) {
        self.configuration = configuration
        pairedServers = credentials.pairingRecords()
        reconcile()
    }

    func update(_ configuration: SendspinPlayerConfiguration) {
        guard configuration != self.configuration else { return }
        configuration.save()
        applyConfiguration(configuration)
    }

    func applicationWillEnterForeground() {
        isForeground = true
        reconcile()
    }

    func applicationDidEnterBackground() {
        guard !Current.isCatalyst else { return }
        isForeground = false
        reconcile()
    }

    func forgetPairedServers() {
        credentials.savePairingRecords([])
        pairedServers = []
    }

    func send(_ command: SendspinControllerCommand) {
        guard let service else { return }
        Task { await service.sendControllerCommand(command) }
    }

    private func reconcile() {
        guard configuration.isEnabled, isForeground || isStreaming else {
            stop(reason: configuration.isEnabled ? .shutdown : .userRequest)
            return
        }
        if let service {
            let settings = configuration.playerSettings
            Task { await service.update(settings: settings) }
            return
        }
        start()
    }

    private func start() {
        retry?.cancel()
        generation += 1
        let generation = generation
        let service = SendspinPlayerService(
            credentials: credentials,
            audio: audio,
            settings: configuration.playerSettings,
            deviceInfo: SendspinDeviceInfo(
                productName: UIDevice.current.model,
                manufacturer: "Apple",
                softwareVersion: Current.clientVersion().description
            ),
            onStatus: { [weak self] status in
                Task { @MainActor in self?.serviceReported(status, generation: generation) }
            },
            onEvent: { [weak self] event in
                Task { @MainActor in self?.serviceReported(event, generation: generation) }
            }
        )
        self.service = service
        status = .starting
        Task { await service.start(port: SendspinListener.defaultPort) }
    }

    private func stop(reason: SendspinGoodbyeReason) {
        retry?.cancel()
        retry = nil
        retryDelay = Constants.firstRetryDelay
        status = .stopped
        isStreaming = false
        nowPlaying = nil
        groupName = nil
        nowPlayingCenter.clear()
        nowPlayingCenter.update(controller: nil)
        guard let service else { return }
        self.service = nil
        generation += 1
        Task { await service.stop(reason: reason) }
    }

    private func serviceReported(_ status: SendspinPlayerStatus, generation: Int) {
        guard generation == self.generation else { return }
        self.status = status
        switch status {
        case .listening, .connected, .playing:
            retryDelay = Constants.firstRetryDelay
        case .failed:
            scheduleRetry()
        case .stopped, .starting:
            break
        }
    }

    private func serviceReported(_ event: SendspinSessionEvent, generation: Int) {
        guard generation == self.generation else { return }
        switch event {
        case .connected:
            break
        case let .groupUpdated(update):
            groupName = update.groupName
        case let .metadata(metadata, positionMs):
            nowPlaying = metadata
            nowPlayingCenter.update(metadata: metadata, positionMs: positionMs)
        case let .controller(controller):
            nowPlayingCenter.update(controller: controller)
        case .streamStarted:
            isStreaming = true
        case .streamEnded:
            isStreaming = false
            // Playing was the only thing keeping the player up in the background.
            if !isForeground {
                reconcile()
            }
        case let .volumeChanged(volume, muted):
            persist { configuration in
                configuration.volume = volume
                configuration.isMuted = muted
            }
        case let .outputDelayChanged(milliseconds):
            persist { $0.outputDelayMs = milliseconds }
        case .paired, .unpaired:
            pairedServers = credentials.pairingRecords()
        }
    }

    /// Saves a change the server made, without echoing it back to the service that reported it.
    private func persist(_ change: (inout SendspinPlayerConfiguration) -> Void) {
        var configuration = configuration
        change(&configuration)
        configuration.save()
        self.configuration = configuration
    }

    /// Opens the port again after the listener failed, backing off so a port that is gone for good
    /// is not retried in a tight loop.
    private func scheduleRetry() {
        guard let failed = service else { return }
        service = nil
        generation += 1
        Task { await failed.stop(reason: .restart) }
        retry?.cancel()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, Constants.maximumRetryDelay)
        retry = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.reconcile()
        }
    }
}
