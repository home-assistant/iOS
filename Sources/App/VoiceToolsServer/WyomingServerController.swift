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

    private var server: WyomingServer?
    private var configuration: VoiceToolsServerConfiguration?
    private var isForeground = true
    /// What the running listener was started with, so a settings change that does not affect it
    /// does not tear a working server down and put it back up.
    private var runningSettings: Settings?

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
        // The server is an App Labs feature, so a setting left on by a TestFlight build stays
        // inert once the same install updates to an App Store build.
        guard AppLabsFeature.isLabsAvailable, configuration.isEnabled, isForeground else {
            stop()
            return
        }

        let port = Self.port(for: configuration)
        let settings = Settings(port: port.rawValue)
        guard runningSettings != settings else { return }

        stop()
        runningSettings = settings
        state = .starting

        let server = WyomingServer(
            port: port,
            serviceName: WyomingServiceCatalog.advertisedDeviceName(),
            // Only used when a client transcribes without naming a language, which Home Assistant
            // never does. The device's own locale, deliberately not Assist's speech setting: what
            // this device serves is configured independently of how Assist behaves in the app.
            fallbackLocale: Locale.current,
            onStateChange: { [weak self] state in
                Task { @MainActor in self?.state = state }
            }
        )
        self.server = server
        Task { await server.start() }
    }

    private func stop() {
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
