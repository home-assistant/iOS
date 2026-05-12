import CoreLocation
import Foundation
import PromiseKit
import Shared
import SwiftUI
import UIKit

class LifecycleManager {
    private let inFlightGreetingManager = InFlightGreetingManager()
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
        inFlightGreetingManager.markColdLaunch()

        Current.backgroundTask(withName: BackgroundTask.lifecycleManagerDidFinishLaunching.rawValue) { _ in
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
        syncNetworkInformation()
    }

    @objc private func didEnterBackground() {
        isActive = false
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
        syncNetworkInformation()
        inFlightGreetingManager.evaluateColdLaunchGreetingIfNeeded()
    }

    private func syncNetworkInformation() {
        Task {
            await Current.connectivity.syncNetworkInformation()
        }
    }
}

final class InFlightGreetingManager {
    private static let lastShownDayKey = "inFlightGreetingLastShownDay"
    private static let toastID = "in-flight-greeting"

    private let userDefaults: UserDefaults
    private let dateProvider: () -> Date
    private let calendarProvider: () -> Calendar
    private let isDebugProvider: () -> Bool
    private let applicationStateProvider: () -> UIApplication.State
    private let isLocationEnabledProvider: (UIApplication.State) -> Bool
    private let locationProvider: () -> Promise<CLLocation>
    private let toastPresenter: () -> Void

    private var shouldEvaluateColdLaunch = false

    init(
        userDefaults: UserDefaults = Current.settingsStore.prefs, // Accessing 'prefs' directly
        dateProvider: @escaping () -> Date = Current.date,
        calendarProvider: @escaping () -> Calendar = Current.calendar,
        isDebugProvider: @escaping () -> Bool = { Current.isDebug },
        applicationStateProvider: @escaping () -> UIApplication.State = { UIApplication.shared.applicationState },
        isLocationEnabledProvider: @escaping (UIApplication.State) -> Bool = { state in
            Current.settingsStore.isLocationEnabled(for: state)
        },
        locationProvider: @escaping () -> Promise<CLLocation> = {
            Current.location.oneShotLocation(.Launch, 10)
        },
        toastPresenter: @escaping () -> Void = {
            guard #available(iOS 18, *), !Current.isCatalyst else { return }

            ToastManager.shared.show(
                id: Self.toastID,
                symbol: "airplane",
                symbolForegroundStyle: (.white, .blue),
                title: Current.localized.string("in_flight_greeting.toast.title", "Localizable"),
                message: Current.localized.string("in_flight_greeting.toast.message", "Localizable"),
                duration: 6
            )
        }
    ) {
        self.userDefaults = userDefaults
        self.dateProvider = dateProvider
        self.calendarProvider = calendarProvider
        self.isDebugProvider = isDebugProvider
        self.applicationStateProvider = applicationStateProvider
        self.isLocationEnabledProvider = isLocationEnabledProvider
        self.locationProvider = locationProvider
        self.toastPresenter = toastPresenter
    }

    func markColdLaunch() {
        shouldEvaluateColdLaunch = true
    }

    func evaluateColdLaunchGreetingIfNeeded() {
        guard shouldEvaluateColdLaunch else { return }
        shouldEvaluateColdLaunch = false

        let applicationState = applicationStateProvider()
        guard applicationState == .active else { return }
        guard isLocationEnabledProvider(applicationState) else { return }
        guard canShowGreetingToday() else { return }

        locationProvider().pipe { [weak self] result in
            guard let self else { return }

            switch result {
            case let .fulfilled(location):
                if InFlightGreetingDetector.isLikelyInFlight(location: location, now: dateProvider()) {
                    toastPresenter()
                    recordGreetingShown()
                }
            case let .rejected(error):
                Current.Log.info("Skipping in-flight greeting because location was unavailable: \(error)")
            }
        }
    }

    func canShowGreetingToday() -> Bool {
        guard !isDebugProvider() else { return true }
        return userDefaults.string(forKey: Self.lastShownDayKey) != currentDayKey()
    }

    func recordGreetingShown() {
        guard !isDebugProvider() else { return }
        userDefaults.set(currentDayKey(), forKey: Self.lastShownDayKey)
    }

    private func currentDayKey() -> String {
        let components = calendarProvider().dateComponents([.year, .month, .day], from: dateProvider())
        return [
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
        ]
        .map { String(format: "%02d", $0) }
        .joined(separator: "-")
    }
}

enum InFlightGreetingDetector {
    private static let minimumFlightSpeed: CLLocationSpeed = 300 / 3.6
    private static let minimumBoostedSpeed: CLLocationSpeed = 250 / 3.6
    private static let minimumAltitude: CLLocationDistance = 1_500
    private static let maximumLocationAge: TimeInterval = 10 * 60
    private static let maximumHorizontalAccuracy: CLLocationAccuracy = 3_000

    static func isLikelyInFlight(location: CLLocation, now: Date) -> Bool {
        guard location.speed >= 0 else { return false }
        guard abs(now.timeIntervalSince(location.timestamp)) <= maximumLocationAge else { return false }
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= maximumHorizontalAccuracy else {
            return false
        }

        if location.speed >= minimumFlightSpeed {
            return true
        }

        return location.speed >= minimumBoostedSpeed && hasAltitudeConfidence(location)
    }

    private static func hasAltitudeConfidence(_ location: CLLocation) -> Bool {
        location.verticalAccuracy >= 0 && location.altitude >= minimumAltitude
    }
}
