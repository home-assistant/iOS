import Foundation
import GRDB

/// The small set of app services `HANetworking` needs but cannot reach through `Current` (importing
/// HACore would be a dependency cycle). HACore populates `HANetworkingEnvironment.current` once at
/// launch; until then, every member has a safe no-op/default so the package is usable (and testable)
/// standalone. This mirrors the codebase's "World" (`Current`) pattern, scoped to networking.
///
/// New seams are added here as networking files move in (connectivity, settings, clock, the
/// reauth-failure handler, …). Inside the package, code reads `HANetworkingEnvironment.current.x`.
public struct HANetworkingEnvironment {
    public static var current = HANetworkingEnvironment()

    /// Logging facade. HACore wires each closure to `Current.Log`; the default drops messages.
    public var log = Log.noop

    /// Current date, injectable for tests. HACore wires this to `Current.date`.
    public var date: () -> Date = Date.init

    /// Running under Mac Catalyst. HACore wires this to `Current.isCatalyst`.
    public var isCatalyst = false

    /// Running inside an app extension. HACore wires this to `Current.isAppExtension`.
    public var isAppExtension = false

    /// Network-state access. `ConnectionInfo` uses this to decide internal-vs-external URL. HACore wires
    /// it to `Current.connectivity`; the concrete fetch (CoreTelephony/macBridge) stays in HACore.
    public var connectivity = Connectivity.noop

    /// Triggers a refresh of a server's cached data from Home Assistant (`Server.refreshAppDatabase`).
    /// HACore wires this to `Current.appDatabaseUpdater.update(server:forceUpdate:)`; no-op by default
    /// (and on watchOS, where there is no app database updater).
    public var refreshAppDatabase: (_ server: Server, _ forceUpdate: Bool) -> Void = { _, _ in }

    /// User-defaults store `ServerManager` uses for deleted/restored-server bookkeeping. HACore wires
    /// this to `Current.settingsStore.prefs`.
    public var prefs: UserDefaults = .standard

    /// The app's bundle identifier, used as the historic Keychain service name. HACore wires this to
    /// `AppConstants.BundleID`.
    public var bundleID: String = Bundle.main.bundleIdentifier ?? "io.home-assistant"

    /// Localized default server name (migration fallback). HACore wires this to `ServerInfo.defaultName`.
    public var defaultServerName: String = "Home Assistant"

    /// The GRDB database `ServerManagerMirrorStore` reads/writes. HACore wires this to
    /// `Current.database`; the default is a throwaway in-memory queue.
    public var database: () -> DatabaseQueue = {
        // swiftlint:disable:next force_try
        try! DatabaseQueue()
    }

    /// Whether the app is a debug build (`AuthenticationRoutes` picks the auth callback scheme from it).
    /// HACore wires this to `Current.appConfiguration == .debug`.
    public var isDebug: Bool = false

    /// Invoked when the server permanently rejects the refresh token (reauthentication needed). HACore
    /// wires this to log a client event, unsubscribe the model manager, disconnect the API connection,
    /// and mark onboarding as needed (`.unauthenticated`). No-op by default.
    public var handleReauthenticationRequired: (_ server: Server, _ statusCode: Int, _ errorDescription: String)
        -> Void = { _, _, _ in }

    public init() {}

    public struct Connectivity {
        public var refreshNetworkInformation: () async -> Void
        public var currentNetworkState: () async -> NetworkState
        public var lastKnownNetworkState: () -> NetworkState

        public init(
            refreshNetworkInformation: @escaping () async -> Void,
            currentNetworkState: @escaping () async -> NetworkState,
            lastKnownNetworkState: @escaping () -> NetworkState
        ) {
            self.refreshNetworkInformation = refreshNetworkInformation
            self.currentNetworkState = currentNetworkState
            self.lastKnownNetworkState = lastKnownNetworkState
        }

        public static let noop = Connectivity(
            refreshNetworkInformation: {},
            currentNetworkState: { NetworkState() },
            lastKnownNetworkState: { NetworkState() }
        )
    }

    /// A minimal leveled logger expressed as closures so the package needs no logging dependency
    /// (XCGLogger lives in HACore). Call sites read like `HANetworkingEnvironment.current.log.error(…)`.
    public struct Log {
        // `Any` (like XCGLogger) so call sites can log strings or error values directly.
        public var error: (Any) -> Void
        public var warning: (Any) -> Void
        public var info: (Any) -> Void
        public var verbose: (Any) -> Void
        public var debug: (Any) -> Void

        public init(
            error: @escaping (Any) -> Void,
            warning: @escaping (Any) -> Void,
            info: @escaping (Any) -> Void,
            verbose: @escaping (Any) -> Void,
            debug: @escaping (Any) -> Void
        ) {
            self.error = error
            self.warning = warning
            self.info = info
            self.verbose = verbose
            self.debug = debug
        }

        public static let noop = Log(
            error: { _ in },
            warning: { _ in },
            info: { _ in },
            verbose: { _ in },
            debug: { _ in }
        )
    }
}
