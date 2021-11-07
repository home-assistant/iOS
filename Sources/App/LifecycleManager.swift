import Foundation
import PromiseKit
import Shared
import UIKit

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

    private var underlyingActive: UInt32 = 0
    private(set) var isActive: Bool {
        get {
            OSAtomicOr32(0, &underlyingActive) != 0
        }
        set {
            if newValue {
                OSAtomicTestAndSet(0, &underlyingActive)
            } else {
                OSAtomicTestAndClear(0, &underlyingActive)
            }
        }
    }

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        if Current.isCatalyst {
            // on macOS, background/foreground is less of a concept
            // on catalina, the app will 'background' and 'foreground' when hidden
            // on big sur and beyond, the background/foreground lifecycle never seems to happen
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(warmConnect),
                name: .init(rawValue: "NSApplicationDidBecomeActiveNotification"),
                object: nil
            )
        } else {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(warmConnect),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
        }
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
            Current.api.then(on: nil) { api in
                api.CreateEvent(
                    eventType: "ios.finished_launching",
                    eventData: api.sharedEventDeviceInfo
                )
            }
        }.cauterize()

        connectAPI(reason: .cold)
    }

    @objc private func willEnterForeground() {
        isActive = true
    }

    @objc private func didEnterBackground() {
        isActive = false

        Current.backgroundTask(withName: "lifecycle-manager-didEnterBackground") { _ in
            Current.api.then(on: nil) { api in
                api.CreateEvent(
                    eventType: "ios.entered_background",
                    eventData: api.sharedEventDeviceInfo
                )
            }
        }.cauterize()

        invalidatePeriodicUpdateTimer()
    }

    private var hasTriggeredWarm = false

    @objc private func warmConnect() {
        if #available(iOS 13, *) {
            if hasTriggeredWarm {
                // iOS 13+ scene API triggers foreground on initial launch, too, so we ignore it
                connectAPI(reason: .warm)
            }
        } else {
            connectAPI(reason: .warm)
        }

        hasTriggeredWarm = true
    }

    @objc private func didBecomeActive() {
        if #available(iOS 13, *) {
            // not necessary as foreground/background always occur
        } else {
            // done for iOS 12's initial startup, which does not foreground
            isActive = true
        }

        Current.backgroundTask(withName: "lifecycle-manager-didBecomeActive") { _ in
            Current.api.then(on: nil) { api in
                api.CreateEvent(
                    eventType: "ios.became_active",
                    eventData: api.sharedEventDeviceInfo
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
        Current.backgroundTask(withName: "connect-api") { _ in
            when(resolved: Current.apis.map { api in
                api.Connect(reason: reason)
            }).asVoid()
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
