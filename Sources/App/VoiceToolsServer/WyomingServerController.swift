import Foundation
import Network
import Shared
import Speech

/// Owns the Wyoming listener for the app: it starts when the user has switched it on and the app is
/// in front, and stops again the moment either stops being true.
///
/// The lifecycle rule is not a simplification of something better. On iOS the process is suspended
/// shortly after it leaves the screen and the socket dies with it, so a listener left running would
/// only advertise a service that answers nothing. Stopping deliberately makes Home Assistant see it
/// go rather than time out. Catalyst has no such suspension, so there the app being open is enough.
@MainActor
final class WyomingServerController: ObservableObject {
    static let shared = WyomingServerController()

    @Published private(set) var state: WyomingServerState = .stopped

    private enum Constants {
        static let firstRetryDelay: TimeInterval = 5
        /// Capped rather than unbounded: a port someone else is holding may be given up at any
        /// time, so this keeps trying for as long as the app runs without filling the log.
        static let maximumRetryDelay: TimeInterval = 300
    }

    private var server: WyomingServer?
    private var configuration: VoiceToolsServerConfiguration?
    private var isForeground = true
    /// What the running listener was started with, so a settings change that does not affect it
    /// does not tear a working server down and put it back up.
    private var runningSettings: Settings?
    /// Which listener the state reports belong to. A listener that has been replaced goes on
    /// reporting as it winds down, and without this its `.cancelled` would land as the state of
    /// the listener that replaced it.
    private var generation = 0
    private var retry: Task<Void, Never>?
    private var retryDelay = Constants.firstRetryDelay

    /// The settings a listener is bound to. The port is all of it: everything else a Wyoming
    /// client asks for is read per request.
    private struct Settings: Equatable {
        let port: UInt16
    }

    /// Reads the stored settings and reconciles the listener with them. Safe to call at any point:
    /// it is what both app launch and every settings change go through.
    func applyConfiguration(_ configuration: VoiceToolsServerConfiguration = VoiceToolsServerConfiguration.config) {
        self.configuration = configuration
        reconcile()
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

    private func reconcile() {
        let configuration = configuration ?? VoiceToolsServerConfiguration.config
        guard configuration.isEnabled, isForeground else {
            stop()
            return
        }

        let port = Self.port(for: configuration)
        let settings = Settings(port: port.rawValue)
        guard runningSettings != settings else { return }

        stop()
        runningSettings = settings
        state = .starting

        generation += 1
        let generation = generation
        let server = WyomingServer(
            port: port,
            serviceName: WyomingServiceCatalog.advertisedDeviceName(),
            // Only used when a client transcribes without naming a language, which Home Assistant
            // never does. The device's own locale, deliberately not Assist's speech setting: what
            // this device serves is configured independently of how Assist behaves in the app.
            fallbackLocale: Locale.current,
            onStateChange: { [weak self] state in
                Task { @MainActor in self?.listener(generation, reported: state) }
            }
        )
        self.server = server
        Task { await server.start() }
    }

    private func listener(_ generation: Int, reported state: WyomingServerState) {
        guard generation == self.generation else { return }
        self.state = state

        switch state {
        case .running:
            retryDelay = Constants.firstRetryDelay
        case .failed:
            listenerFailed()
        case .stopped, .starting:
            break
        }
    }

    /// Forgets the settings the dead listener was bound to and lines up another attempt.
    ///
    /// Nothing else is going to notice it died. On the Mac the app sits in front for days at a
    /// time, so there is no foreground to come back on, and `reconcile` would read these settings
    /// as the ones already applied and leave the dead listener where it is. Clearing them is what
    /// lets the retry bind the port again.
    ///
    /// Not private only so a test can reach it: there is no way to make a real `NWListener` fail
    /// on demand from a test runner.
    func listenerFailed() {
        runningSettings = nil
        scheduleRetry()
    }

    /// Binds the port again after a listener failed — a Wi-Fi interface coming and going, or
    /// another process holding the port while it shuts down — backing off so a port that is gone
    /// for good is not retried in a tight loop.
    private func scheduleRetry() {
        retry?.cancel()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, Constants.maximumRetryDelay)
        retry = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.reconcile()
        }
    }

    private func stop() {
        retry?.cancel()
        retry = nil
        guard let server else {
            state = .stopped
            return
        }
        self.server = nil
        runningSettings = nil
        state = .stopped
        Task { await server.stop() }
    }

    /// A port stored outside the valid range — or left at zero, which would make the system pick an
    /// arbitrary one Home Assistant could not be pointed at — falls back to the default.
    private static func port(for configuration: VoiceToolsServerConfiguration) -> NWEndpoint.Port {
        guard let rawValue = UInt16(exactly: configuration.port), rawValue > 0,
              let port = NWEndpoint.Port(rawValue: rawValue) else {
            // The default is a valid port number, so the fallback below never actually runs.
            return NWEndpoint.Port(rawValue: UInt16(VoiceToolsServerConfiguration.defaultPort)) ?? .any
        }
        return port
    }

    /// Whether speech recognition has been granted. Text-to-speech works without it, so this only
    /// gates the transcription half and the settings screen says so.
    ///
    /// `nonisolated` because the settings screen reads it while building itself, which the settings
    /// list does off the main actor; the underlying authorization check is thread-safe.
    nonisolated static var isSpeechRecognitionAuthorized: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    /// Asks for speech recognition up front, when the user switches the server on, rather than in
    /// the middle of Home Assistant's first request where there is nothing on screen to explain it.
    static func requestSpeechRecognitionAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
