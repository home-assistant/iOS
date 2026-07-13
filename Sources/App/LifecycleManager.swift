import Foundation
import GRDB
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
        Current.backgroundTask(withName: BackgroundTask.lifecycleManagerDidFinishLaunching.rawValue) { _ in
            when(fulfilled: Current.apis.map { api in
                api.CreateEvent(
                    eventType: "ios.finished_launching",
                    eventData: api.sharedEventDeviceInfo
                )
            })
        }.cauterize()

        // Resolve the network info (SSID) before the first connect so we don't pick the remote URL while on
        // the home network and get rejected.
        Task { @MainActor [periodicUpdateManager] in
            await Current.connectivity.refreshNetworkInformation()
            periodicUpdateManager.connectAPI(reason: .cold)
        }
    }

    @objc private func willEnterForeground() {
        isActive = true
        NotificationCenter.default.post(name: Database.resumeNotification, object: self)
        refreshNetworkInformation()
        syncLiveActivities()
    }

    /// Reconcile running Live Activities with Core on every foreground, releasing tokens for any
    /// that ended while the app was backgrounded so Core stops pushing to them.
    private func syncLiveActivities() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 17.2, *) {
            Task { await Current.liveActivityRegistry?.reattach() }
        }
        #endif
    }

    @objc private func didEnterBackground() {
        isActive = false
        NotificationCenter.default.post(name: Database.suspendNotification, object: self)
        Current.backgroundTask(withName: BackgroundTask.lifecycleManagerDidEnterBackground.rawValue) { _ in
            when(fulfilled: Current.apis.map { api in
                api.CreateEvent(
                    eventType: "ios.entered_background",
                    eventData: api.sharedEventDeviceInfo
                )
            })
        }.cauterize()

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
        Current.backgroundTask(withName: BackgroundTask.lifecycleManagerDidBecomeActive.rawValue) { _ in
            when(fulfilled: Current.apis.map { api in
                api.CreateEvent(
                    eventType: "ios.became_active",
                    eventData: api.sharedEventDeviceInfo
                )
            })
        }.cauterize()
        refreshNetworkInformation()
    }

    private func refreshNetworkInformation() {
        Task {
            await Current.connectivity.refreshNetworkInformation()
        }
    }
}
