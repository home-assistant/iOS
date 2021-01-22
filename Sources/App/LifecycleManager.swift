import Foundation
import UIKit
import Shared
import PromiseKit
#if !targetEnvironment(macCatalyst)
import Lokalise
#endif

class LifecycleManager {
    private var periodicUpdateTimer: Timer? {
        willSet {
            if periodicUpdateTimer != newValue {
                periodicUpdateTimer?.invalidate()
            }
        }
    }
    static var supportsBackgroundPeriodicUpdates: Bool {
        Current.isCatalyst
    }

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    func didFinishLaunching() {
        Current.backgroundTask(withName: "lifecycle-manager-didFinishLaunching") { _ in
            Current.api.then { api in
                api.CreateEvent(
                    eventType: "ios.finished_launching",
                    eventData: HomeAssistantAPI.sharedEventDeviceInfo
                )
            }
        }.cauterize()

        #if !targetEnvironment(macCatalyst)
        Lokalise.shared.checkForUpdates { (updated, error) in
            if let error = error {
                Current.Log.error("Error when updating Lokalise: \(error)")
            } else {
                Current.Log.info("Lokalise updated? \(updated)")
            }
        }
        #endif

        connectAPI(reason: .cold)
    }

    @objc private func didEnterBackground() {
        Current.backgroundTask(withName: "lifecycle-manager-didEnterBackground") { _ in
            Current.api.then { api in
                api.CreateEvent(
                    eventType: "ios.entered_background",
                    eventData: HomeAssistantAPI.sharedEventDeviceInfo
                )
            }
        }.cauterize()

        invalidatePeriodicUpdateTimer()
    }

    private var hasEnteredForeground = false

    @objc private func willEnterForeground() {
        if #available(iOS 13, *) {
            if hasEnteredForeground {
                // iOS 13+ scene API triggers foreground on initial launch, too, so we ignore it
                connectAPI(reason: .warm)
            }
        } else {
            connectAPI(reason: .warm)
        }

        hasEnteredForeground = true
    }

    @objc private func didBecomeActive() {
        Current.backgroundTask(withName: "lifecycle-manager-didBecomeActive") { _ in
            Current.api.then { api in
                api.CreateEvent(
                    eventType: "ios.became_active",
                    eventData: HomeAssistantAPI.sharedEventDeviceInfo
                )
            }
        }.cauterize()
    }

    private func invalidatePeriodicUpdateTimer() {
        if !Self.supportsBackgroundPeriodicUpdates {
            periodicUpdateTimer = nil
        }
    }

    private func schedulePeriodicUpdateTimer() {
        guard periodicUpdateTimer == nil || periodicUpdateTimer?.isValid == false else {
            return
        }

        guard Self.supportsBackgroundPeriodicUpdates || UIApplication.shared.applicationState != .background else {
            // it's fine to schedule, but we don't wanna fire two when we come back to foreground later
            Current.Log.info("not scheduling periodic update; backgrounded")
            return
        }

        guard let interval = Current.settingsStore.periodicUpdateInterval else {
            Current.Log.info("not scheduling periodic update; disabled")
            return
        }

        periodicUpdateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.connectAPI(reason: .periodic)
        }
    }

    private func connectAPI(reason: HomeAssistantAPI.ConnectReason) {
        return Current.backgroundTask(withName: "connect-api") { _ in
            Current.api.then { api in
                api.Connect(reason: reason)
            }
        }.done {
            Current.Log.info("Connect finished for reason \(reason)")
        }.catch { error in
            // if the error is e.g. token is invalid, we'll force onboarding through status-code-watching mechanisms
            Current.Log.error("Couldn't connect for reason \(reason): \(error)")
        }.finally {
            self.schedulePeriodicUpdateTimer()
        }
    }

}
