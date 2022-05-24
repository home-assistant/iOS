import Foundation
import PromiseKit
import Shared
import UIKit

class LifecycleManager {
    private let periodicUpdateManager = PeriodicUpdateManager(
        applicationStateGetter: { UIApplication.shared.applicationState }
    )
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
            when(fulfilled: Current.apis.map { api in
                api.CreateEvent(
                    eventType: "ios.finished_launching",
                    eventData: api.sharedEventDeviceInfo
                )
            })
        }.cauterize()

        periodicUpdateManager.connectAPI(reason: .cold)
    }

    @objc private func willEnterForeground() {
        isActive = true
    }

    @objc private func didEnterBackground() {
        isActive = false

        Current.backgroundTask(withName: "lifecycle-manager-didEnterBackground") { _ in
            when(fulfilled: Current.apis.map { api in
                api.CreateEvent(
                    eventType: "ios.entered_background",
                    eventData: api.sharedEventDeviceInfo
                )
            })
        }.cauterize()

        periodicUpdateManager.invalidatePeriodicUpdateTimer(forBackground: true)
    }

    private var hasTriggeredWarm = false

    @objc private func warmConnect() {
        if #available(iOS 13, *) {
            if hasTriggeredWarm {
                // iOS 13+ scene API triggers foreground on initial launch, too, so we ignore it
                periodicUpdateManager.connectAPI(reason: .warm)
            }
        } else {
            periodicUpdateManager.connectAPI(reason: .warm)
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
            when(fulfilled: Current.apis.map { api in
                api.CreateEvent(
                    eventType: "ios.became_active",
                    eventData: api.sharedEventDeviceInfo
                )
            })
        }.cauterize()
    }
}
