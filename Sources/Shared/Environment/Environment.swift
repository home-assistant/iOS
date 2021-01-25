//
//  Environment.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 6/15/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import PromiseKit
import RealmSwift
import XCGLogger
import CoreMotion
import CoreLocation
import Version

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

public var Current = Environment()
/// The current "operating envrionment" the app. Implementations can be swapped out to facilitate better
/// unit tests.
public class Environment {
    internal init() {
        PromiseKit.conf.Q = (map: nil, return: .main)
        PromiseKit.conf.logHandler = { event in
            Current.Log.info {
                switch event {
                case .waitOnMainThread:
                    return "PromiseKit: warning: `wait()` called on main thread!"
                case .pendingPromiseDeallocated:
                    return "PromiseKit: warning: pending promise deallocated"
                case .pendingGuaranteeDeallocated:
                    return "PromiseKit: warning: pending guarantee deallocated"
                case .cauterized (let error):
                    return "PromiseKit:cauterized-error: \(error)"
                }
            }
        }

        let crashReporter = CrashReporterImpl()
        self.crashReporter = crashReporter
        crashReporter.setup(environment: self)
    }

    /// Crash reporting and related metadata gathering
    public var crashReporter: CrashReporter

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

    private var underlyingAPI: Promise<HomeAssistantAPI>?

    public var api: Promise<HomeAssistantAPI> {
        get {
            if let value = underlyingAPI {
                return value
            } else if !isRunningTests, let value = HomeAssistantAPI() {
                underlyingAPI = .value(value)
                return .value(value)
            } else {
                return .init(error: HomeAssistantAPI.APIError.notConfigured)
            }
        }
        set {
            underlyingAPI = newValue
        }
    }
    public func resetAPI() {
        underlyingAPI = nil
    }

    public var modelManager = ModelManager()
    public var tokenManager: TokenManager?

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
        $0.register(provider: InputDeviceSensor.self)
        $0.register(provider: DisplaySensor.self)
        $0.register(provider: ActiveSensor.self)
        $0.register(provider: FrontmostAppSensor.self)
        $0.register(provider: LastUpdateSensor.self)
    }

    public var localized = LocalizedManager()

    public var tags: TagManager = EmptyTagManager()

    public var updater: Updater = Updater()
    public var serverAlerter: ServerAlerter = ServerAlerter()

    #if os(watchOS)
    public var backgroundRefreshScheduler = WatchBackgroundRefreshScheduler()
    #endif

    #if targetEnvironment(macCatalyst)
    public var macBridge: MacBridge = {
        guard let pluginUrl = Bundle(for: Environment.self).builtInPlugInsURL,
              let bundle = Bundle(url: pluginUrl.appendingPathComponent("MacBridge.bundle"))
        else {
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

    public lazy var activeState: ActiveStateManager = { ActiveStateManager() }()

    public lazy var serverVersion: () -> Version? = { [settingsStore] in settingsStore.serverVersion }
    public lazy var clientVersion: () -> Version = { Constants.clientVersion }

    public var onboardingObservation = OnboardingStateObservation()

    public var isPerformingSingleShotLocationQuery = false

    public var backgroundTask: HomeAssistantBackgroundTaskRunner = ProcessInfoBackgroundTaskRunner()

    // Use of 'appConfiguration' is preferred, but sometimes Beta builds are done as releases.
    public var isTestFlight = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
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
        return NSClassFromString("XCTest") != nil
    }

    public var isBackgroundRequestsImmediate = { true }

    public var appConfiguration: AppConfiguration {
        if isFastlaneSnapshot {
            return .FastlaneSnapshot
        } else if isDebug {
            return .Debug
        } else if (Bundle.main.bundleIdentifier ?? "").lowercased().contains("beta") && isTestFlight {
            return .Beta
        } else {
            return .Release
        }
    }

    public var Log: XCGLogger = {
        if NSClassFromString("XCTest") != nil {
            return XCGLogger()
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

        let logPath = Constants.LogsDirectory.appendingPathComponent("log.txt", isDirectory: false)

        // Create a file log destination
        let isTestFlight = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        let fileDestination = AutoRotatingFileDestination(writeToFile: logPath,
                                                          identifier: "advancedLogger.fileDestination",
                                                          shouldAppend: true,
                                                          maxFileSize: 10_485_760,
                                                          maxTimeInterval: 86400,
                                                          // archived logs + 1 current, so realy this is -1'd
                                                          targetMaxLogFiles: isTestFlight ? 8 : 4)

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
            return CMMotionActivityManager.authorizationStatus() == .authorized
        }
        public var isActivityAvailable: () -> Bool = CMMotionActivityManager.isActivityAvailable
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

    /// Wrapper around CLGeocoder
    public struct Geocoder {
        public var geocode: (CLLocation) -> Promise<[CLPlacemark]> = CLGeocoder.geocode(location:)
    }
    public var geocoder = Geocoder()

    /// Wrapper around One Shot
    public struct Location {
        public lazy var oneShotLocation: (_ timeout: TimeInterval) -> Promise<CLLocation> = {
            CLLocationManager.oneShotLocation(timeout: $0)
        }
    }
    public var location = Location()

    public var connectivity = ConnectivityWrapper()
}
