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
    case TestFlight
    case AppStore
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

    public var deviceIDProvider: (() -> String)!

    public var isPerformingSingleShotLocationQuery = false

    public var syncMonitoredRegions: (() -> Void)?

    public func updateWith(authenticatedAPI: HomeAssistantAPI) {
        if authenticatedAPI.authenticationMethodString == "modern" {
            guard let tokenManager = authenticatedAPI.tokenManager else {
                assertionFailure("Should have had token manager")
                return
            }

            self.tokenManager = tokenManager
        }

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
            return .TestFlight
        } else {
            return .AppStore
        }
    }
}
