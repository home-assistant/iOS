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
#if os(iOS)
import Fabric
import Crashlytics
#endif

public enum AppConfiguration: Int, CaseIterable {
    case FastlaneSnapshot
    case Debug
    case Beta
    case Release

    var description: String {
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
    /// Provides URLs usable for storing data.
    public var date: () -> Date = Date.init

    /// Provides the Client Event store used for local logging.
    public var clientEventStore = ClientEventStore()

    /// Provides the Realm used for many data storage tasks.
    public var realm: () -> Realm = Realm.live

    public var tokenManager: TokenManager?

    public var settingsStore = SettingsStore()

    #if os(iOS)
    public var authenticationControllerPresenter: ((UIViewController) -> Void)?
    #endif

    public var signInRequiredCallback: (() -> Void)?

    public var onboardingComplete: (() -> Void)?

    public var isPerformingSingleShotLocationQuery = false

    public var syncMonitoredRegions: (() -> Void)?

    public func updateWith(authenticatedAPI: HomeAssistantAPI) {
        self.tokenManager = authenticatedAPI.tokenManager
        self.settingsStore.connectionInfo = authenticatedAPI.connectionInfo
    }

    // This is private because the use of 'appConfiguration' is preferred.
    private let isTestFlight = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"

    private let isFastlaneSnapshot = UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT")

    // This can be used to add debug statements.
    public var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    public var appConfiguration: AppConfiguration {
        if isFastlaneSnapshot {
            return .FastlaneSnapshot
        } else if isDebug {
            return .Debug
        } else if isTestFlight {
            return .Beta
        } else {
            return .Release
        }
    }

    public var Log: XCGLogger = {
        // Create a logger object with no destinations
        let log = XCGLogger(identifier: "advancedLogger", includeDefaultDestinations: false)

        // Create a destination for the system console log (via NSLog)
        let systemDestination = AppleSystemLogDestination(identifier: "advancedLogger.systemDestination")

        // Optionally set some configuration options
        systemDestination.outputLevel = .verbose
        systemDestination.showLogIdentifier = false
        systemDestination.showFunctionName = true
        systemDestination.showThreadName = true
        systemDestination.showLevel = true
        systemDestination.showFileName = true
        systemDestination.showLineNumber = true
        systemDestination.showDate = true

        // Add the destination to the logger
        log.add(destination: systemDestination)

        let logPath = Constants.LogsDirectory.appendingPathComponent("log.txt", isDirectory: false)

        // Create a file log destination
        let fileDestination = AutoRotatingFileDestination(writeToFile: logPath,
                                                          identifier: "advancedLogger.fileDestination",
                                                          shouldAppend: true)

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

        #if os(iOS)
        log.add(destination: CrashlyticsLogDestination())
        #endif

        // Add basic app info, version info etc, to the start of the logs
        log.logAppDetails()

        return log
    }()

    #if os(iOS)
    public func loadCrashlytics() {
        if self.crashlyticsEnabled {
            Current.Log.warning("Enabling Firebase Crashlytics!")
            Fabric.with([Crashlytics.self])
        } else {
            Current.Log.warning("Refusing to enable Firebase Crashlytics!")
        }
    }

    public func setCrashlyticsEnabled(enabled: Bool) {
        Current.Log.warning("Firebase Crashlytics is now: \(enabled)")
        UserDefaults(suiteName: Constants.AppGroupID)!.set(enabled, forKey: "crashlyticsEnabled")
        if enabled {
            Fabric.with([Crashlytics.self])
        }
    }

    public var crashlyticsEnabled: Bool {
        return UserDefaults(suiteName: Constants.AppGroupID)!.bool(forKey: "crashlyticsEnabled")
    }
    #endif
}
