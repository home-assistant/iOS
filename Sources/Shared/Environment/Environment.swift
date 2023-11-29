import CoreLocation
import CoreMotion
import Foundation
import HAKit
import PromiseKit
import RealmSwift
import Version
import XCGLogger

public enum AppConfiguration: Int, CaseIterable, CustomStringConvertible {
    case FastlaneSnapshot
    case Debug
    case Beta
    case Release

    public var description: String {
        switch self {
        case .FastlaneSnapshot:
            return "fastlane"
        case .Debug:
            return "debug"
        case .Beta:
            return "beta"
        case .Release:
            return "release"
        }
    }
}

private var underlyingWasSetUp: UInt32 = 0
private var underlyingCurrent = AppEnvironment()

public var Current: AppEnvironment {
    get {
        let result = underlyingCurrent
        if OSAtomicTestAndSetBarrier(0, &underlyingWasSetUp) == false {
            // we only want to run setup once, but we _must_ have 'Current' work during it to allow 'Current' to be
            // reentrant, which is a requirement for touching things like Log but also touching more unexpected
            // things like accessing any L10n helper value, which funnels through Current as well.
            result.setup()
        }
        return result
    }
    set {
        underlyingCurrent = newValue
    }
}

/// The current "operating envrionment" the app. Implementations can be swapped out to facilitate better
/// unit tests.
public class AppEnvironment {
    internal init() {
        PromiseKit.conf.logHandler = { event in
            Current.Log.info {
                switch event {
                case .waitOnMainThread:
                    return "PromiseKit: warning: `wait()` called on main thread!"
                case .pendingPromiseDeallocated:
                    return "PromiseKit: warning: pending promise deallocated"
                case .pendingGuaranteeDeallocated:
                    return "PromiseKit: warning: pending guarantee deallocated"
                case let .cauterized(error):
                    return "PromiseKit:cauterized-error: \(error)"
                }
            }
        }
        HAGlobal.log = { level, log in
            let string = "WebSocket: \(log.replacingOccurrences(of: "\n", with: " "))"

            switch level {
            case .info: Current.Log.info(string)
            case .error: Current.Log.error(string)
            }
        }
    }

    internal func setup() {
        _ = Current // just to make sure we don't crash for this case

        (crashReporter as? CrashReporterImpl)?.setup()
        (servers as? ServerManagerImpl)?.setup()
    }

    /// Crash reporting and related metadata gathering
    public var crashReporter: CrashReporter = CrashReporterImpl()

    /// Provides URLs usable for storing data.
    public var date: () -> Date = Date.init
    public var calendar: () -> Calendar = { Calendar.autoupdatingCurrent }

    /// Provides the Client Event store used for local logging.
    public var clientEventStore = ClientEventStore()

    /// Provides the Realm used for many data storage tasks.
    public var realm: () -> Realm = Realm.live

    #if os(iOS)
    public var realmFatalPresentation: ((UIViewController) -> Void)?
    #endif

    public var style: Style = .init()

    public var servers: ServerManager = ServerManagerImpl()

    public var cachedApis = [Identifier<Server>: HomeAssistantAPI]()

    public var apis: [HomeAssistantAPI] { servers.all.map(api(for:)) }

    public func api(for server: Server) -> HomeAssistantAPI {
        if let existing = cachedApis[server.identifier] {
            return existing
        } else {
            let api = HomeAssistantAPI(server: server, urlConfig: .default)
            cachedApis[server.identifier] = api
            return api
        }
    }

    private var underlyingAPI: Promise<HomeAssistantAPI>?

    public var modelManager = ModelManager()

    public var settingsStore = SettingsStore()

    public var webhooks = with(WebhookManager()) {
        // ^ because background url session identifiers cannot be reused, this must be a singleton-ish
        $0.register(responseHandler: WebhookResponseUpdateSensors.self, for: .updateSensors)
        $0.register(responseHandler: WebhookResponseLocation.self, for: .location)
        $0.register(responseHandler: WebhookResponseServiceCall.self, for: .serviceCall)
        $0.register(responseHandler: WebhookResponseUpdateComplications.self, for: .updateComplications)
    }

    public var sensors = with(SensorContainer()) {
        $0.register(provider: ActivitySensor.self)
        $0.register(provider: PedometerSensor.self)
        $0.register(provider: BatterySensor.self)
        $0.register(provider: StorageSensor.self)
        $0.register(provider: ConnectivitySensor.self)
        $0.register(provider: GeocoderSensor.self)
        $0.register(provider: InputOutputDeviceSensor.self)
        $0.register(provider: DisplaySensor.self)
        $0.register(provider: ActiveSensor.self)
        $0.register(provider: FrontmostAppSensor.self)
        $0.register(provider: FocusSensor.self)
        $0.register(provider: LastUpdateSensor.self)
    }

    public var localized = LocalizedManager()

    public var tags: TagManager = EmptyTagManager()

    public var updater = Updater()
    public var serverAlerter = ServerAlerter()
    public var notificationAttachmentManager: NotificationAttachmentManager = NotificationAttachmentManagerImpl()

    #if os(watchOS)
    public var backgroundRefreshScheduler = WatchBackgroundRefreshScheduler()
    #endif

    #if targetEnvironment(macCatalyst)
    public var macBridge: MacBridge = {
        guard let pluginUrl = Bundle(for: AppEnvironment.self).builtInPlugInsURL,
              let bundle = Bundle(url: pluginUrl.appendingPathComponent("MacBridge.bundle")) else {
            fatalError("couldn't load mac bridge bundle")
        }

        bundle.load()

        if let principalClass = bundle.principalClass as? MacBridge.Type {
            return principalClass.init()
        } else {
            fatalError("couldn't load mac bridge principal class")
        }
    }()
    #endif

    public lazy var activeState: ActiveStateManager = .init()

    public lazy var clientVersion: () -> Version = { Constants.clientVersion }

    public var onboardingObservation = OnboardingStateObservation()

    public var isPerformingSingleShotLocationQuery = false

    public var backgroundTask: HomeAssistantBackgroundTaskRunner = ProcessInfoBackgroundTaskRunner()

    // Use of 'appConfiguration' is preferred, but sometimes Beta builds are done as releases.
    public var isTestFlight = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    #if os(iOS)
    public var isAppExtension = Constants.BundleID != Bundle.main.bundleIdentifier
    #elseif os(watchOS)
    public var isAppExtension = false
    #endif
    public var isAppStore: Bool = {
        do {
            // https://developer.apple.com/library/archive/technotes/tn2259/_index.html suggested method
            if let url = Bundle.main.appStoreReceiptURL {
                // url is possibly provided but doesn't exist on disk
                _ = try Data(contentsOf: url)
                return true
            } else {
                return false
            }
        } catch {
            return false
        }
    }()

    public var isCatalyst: Bool = {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }()

    private let isFastlaneSnapshot = UserDefaults(suiteName: Constants.AppGroupID)!.bool(forKey: "FASTLANE_SNAPSHOT")

    // This can be used to add debug statements.
    public var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    public var isRunningTests: Bool {
        NSClassFromString("XCTest") != nil
    }

    public var isBackgroundRequestsImmediate = {
        #if os(watchOS)
        true
        #else
        false
        #endif
    }

    public var isForegroundApp = { false }

    public var appConfiguration: AppConfiguration {
        if isFastlaneSnapshot {
            return .FastlaneSnapshot
        } else if isDebug {
            return .Debug
        } else if (Bundle.main.bundleIdentifier ?? "").lowercased().contains("beta"), isTestFlight {
            return .Beta
        } else {
            return .Release
        }
    }

    public var Log: XCGLogger = {
        if NSClassFromString("XCTest") != nil {
            let logger = XCGLogger()
            logger.outputLevel = .verbose
            return logger
        }

        // Create a logger object with no destinations
        let log = XCGLogger(identifier: "advancedLogger", includeDefaultDestinations: false)

        #if DEBUG
        log.dateFormatter = with(DateFormatter()) {
            $0.dateFormat = "HH:mm:ss.SSS"
            $0.locale = Locale.current
        }

        log.add(destination: with(ConsoleDestination()) {
            $0.outputLevel = .verbose
            $0.showLogIdentifier = false
            $0.showFunctionName = true
            $0.showThreadName = true
            $0.showLevel = true
            $0.showFileName = true
            $0.showLineNumber = true
            $0.showDate = true
        })
        #endif

        let logPath = Constants.LogsDirectory.appendingPathComponent(
            ProcessInfo.processInfo.processName + ".txt",
            isDirectory: false
        )

        // Create a file log destination
        let isTestFlight = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        let fileDestination = AutoRotatingFileDestination(
            writeToFile: logPath,
            identifier: "advancedLogger.fileDestination",
            shouldAppend: true,
            maxFileSize: 10_485_760,
            maxTimeInterval: 86400,
            // archived logs + 1 current, so realy this is -1'd
            targetMaxLogFiles: isTestFlight ? 8 : 4
        )

        // Optionally set some configuration options
        fileDestination.outputLevel = .verbose
        fileDestination.showLogIdentifier = false
        fileDestination.showFunctionName = true
        fileDestination.showThreadName = true
        fileDestination.showLevel = true
        fileDestination.showFileName = true
        fileDestination.showLineNumber = true
        fileDestination.showDate = true

        // Process this destination in the background
        fileDestination.logQueue = XCGLogger.logQueue

        // Add the destination to the logger
        log.add(destination: fileDestination)

        // Add basic app info, version info etc, to the start of the logs
        log.logAppDetails()

        return log
    }()

    /// Wrapper around CMMotionActivityManager
    public struct Motion {
        private let underlyingManager = CMMotionActivityManager()
        public var isAuthorized: () -> Bool = {
            guard !Current.isCatalyst else { return false }
            return CMMotionActivityManager.authorizationStatus() == .authorized
        }

        public var isActivityAvailable: () -> Bool = {
            #if os(iOS) && targetEnvironment(simulator)
            return { true }
            #else
            return CMMotionActivityManager.isActivityAvailable
            #endif
        }()

        public lazy var queryStartEndOnQueueHandler: (
            Date, Date, OperationQueue, @escaping CMMotionActivityQueryHandler
        ) -> Void = { [underlyingManager] start, end, queue, handler in
            underlyingManager.queryActivityStarting(from: start, to: end, to: queue, withHandler: handler)
        }
    }

    public var motion = Motion()

    /// Wrapper around CMPedometeer
    public struct Pedometer {
        private let underlyingPedometer = CMPedometer()
        public var isAuthorized: () -> Bool = {
            guard !Current.isCatalyst else { return false }
            return CMPedometer.authorizationStatus() == .authorized
        }

        public var isStepCountingAvailable: () -> Bool = CMPedometer.isStepCountingAvailable
        public lazy var queryStartEndHandler: (
            Date, Date, @escaping CMPedometerHandler
        ) -> Void = { [underlyingPedometer] start, end, handler in
            underlyingPedometer.queryPedometerData(from: start, to: end, withHandler: handler)
        }
    }

    public var pedometer = Pedometer()

    public var device = DeviceWrapper()

    public var matter = MatterWrapper()

    /// Wrapper around CLGeocoder
    public struct Geocoder {
        public var geocode: (CLLocation) -> Promise<[CLPlacemark]> = CLGeocoder.geocode(location:)
    }

    public var geocoder = Geocoder()

    /// Wrapper around One Shot
    public struct Location {
        public lazy var oneShotLocation: (
            _ trigger: LocationUpdateTrigger,
            _ remaining: TimeInterval?
        ) -> Promise<CLLocation> = {
            CLLocationManager.oneShotLocation(timeout: $0.oneShotTimeout(maximum: $1))
        }
    }

    public var location = Location()

    public var connectivity = ConnectivityWrapper()

    public var focusStatus = FocusStatusWrapper()

    public var diskCache: DiskCache = DiskCacheImpl()
}
