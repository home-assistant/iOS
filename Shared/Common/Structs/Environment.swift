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

    public var authenticationControllerPresenter: ((UIViewController) -> Void)?

    public var signInRequiredCallback: (() -> Void)?

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
}
