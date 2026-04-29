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
        periodicUpdateManager.connectAPI(reason: .cold)
    }

    @objc private func willEnterForeground() {
        isActive = true
        syncNetworkInformation()
    }

    @objc private func didEnterBackground() {
        isActive = false
        periodicUpdateManager.invalidatePeriodicUpdateTimer(forBackground: true)
        DataWidgetsUpdater.update()
    }

    private var hasTriggeredWarm = false

    @objc private func warmConnect() {
        if hasTriggeredWarm {
            // iOS 13+ scene API triggers foreground on initial launch, too, so we ignore it
            periodicUpdateManager.connectAPI(reason: .warm)
        }
        hasTriggeredWarm = true
    }

    @objc private func didBecomeActive() {
        syncNetworkInformation()
    }

    private func syncNetworkInformation() {
        Task {
            await Current.connectivity.syncNetworkInformation()
        }
    }
}
