import Foundation
import Shared
import UIKit

/// Coordinates the "have a great flight" greeting: watches cabin pressure while the app is in the
/// foreground, runs flight detection when the app becomes active or the web view loses connection,
/// shows the greeting toast at most once per flight, and caches detection results so repeated checks
/// stay cheap.
@MainActor
final class FlightGreetingManager {
    static let shared = FlightGreetingManager()

    private static let toastID = "flight-greeting"
    private static let toastDuration: TimeInterval = 5
    /// One greeting per flight: suppress repeats until well after even a long-haul leg.
    private static let greetingCooldown: TimeInterval = 6 * 60 * 60
    private static let lastGreetingDateKey = "flightGreetingLastShownDate"
    /// How long a detection result stays valid before a caller triggers a fresh check. A positive
    /// stays valid for a while (the flight isn't ending soon); a negative retries sooner, but not so
    /// soon that back-to-back checks keep the GPS running continuously.
    private static let positiveDetectionValidity: TimeInterval = 10 * 60
    private static let negativeDetectionValidity: TimeInterval = 2 * 60

    private var cachedDetection: (isFlying: Bool, date: Date)?
    private var detectionTask: Task<Bool, Never>?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var didEnterBackgroundObserver: NSObjectProtocol?

    func start() {
        guard didBecomeActiveObserver == nil else { return }
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                FlightGreetingManager.shared.appDidBecomeActive()
            }
        }
        didEnterBackgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                CabinPressureMonitor.shared.stop()
            }
        }
    }

    /// Whether the user currently appears to be on a plane. Results are cached briefly and
    /// concurrent callers share a single detection pass.
    func isCurrentlyFlying() async -> Bool {
        if let cachedDetection {
            let validity = cachedDetection.isFlying
                ? Self.positiveDetectionValidity
                : Self.negativeDetectionValidity
            if Current.date().timeIntervalSince(cachedDetection.date) < validity {
                return cachedDetection.isFlying
            }
        }
        if let detectionTask {
            return await detectionTask.value
        }
        let task = Task { await FlightDetector.isLikelyFlying() }
        detectionTask = task
        let isFlying = await task.value
        cachedDetection = (isFlying, Current.date())
        detectionTask = nil
        return isFlying
    }

    /// Shows the greeting toast, respecting the user setting and the once-per-flight cooldown.
    func presentGreetingToastIfAllowed() {
        guard Current.settingsStore.flightGreetingsEnabled, canGreet else { return }
        guard #available(iOS 18, *) else { return }
        ToastPresenter.shared.show(
            id: Self.toastID,
            symbol: .airplane,
            symbolForegroundStyle: (.white, .haPrimary),
            title: L10n.FlightGreetings.greeting,
            duration: Self.toastDuration
        )
        prefs.set(Current.date(), forKey: Self.lastGreetingDateKey)
        // The greeting for this flight has been shown, so there is nothing left for the barometer to
        // tell us until the cooldown expires.
        CabinPressureMonitor.shared.stop()
    }

    private func appDidBecomeActive() {
        startPressureMonitoringIfNeeded()
        greetIfFlying()
    }

    /// Keeps the barometer running while the app is in the foreground and a greeting is still
    /// possible, so a flight can announce itself instead of only being noticed when something happens
    /// to ask. Detection used to be purely on demand, which meant a single failed check at the moment
    /// the app opened was the end of it.
    private func startPressureMonitoringIfNeeded() {
        // The toast itself needs iOS 18, so below that there is nothing detection could lead to.
        guard #available(iOS 18, *), Current.settingsStore.flightGreetingsEnabled, canGreet else {
            CabinPressureMonitor.shared.stop()
            return
        }
        CabinPressureMonitor.shared.start { [weak self] _ in
            Task { @MainActor in
                self?.cabinPressureEvidenceDidChange()
            }
        }
    }

    private func cabinPressureEvidenceDidChange() {
        guard Current.settingsStore.flightGreetingsEnabled, canGreet else { return }
        guard FlightDetector.cabinPressureIndicatesFlight else { return }
        // Skip the detection pass the cached positive would otherwise trigger: the barometer has
        // already answered, and the GPS leg of detection has nothing to add.
        cachedDetection = (true, Current.date())
        presentGreetingToastIfAllowed()
    }

    private func greetIfFlying() {
        // Skip detection entirely when the greeting couldn't show anyway.
        guard Current.settingsStore.flightGreetingsEnabled, canGreet else { return }
        Task {
            guard await isCurrentlyFlying() else { return }
            presentGreetingToastIfAllowed()
        }
    }

    private var canGreet: Bool {
        guard let lastGreeting = prefs.object(forKey: Self.lastGreetingDateKey) as? Date else { return true }
        return Current.date().timeIntervalSince(lastGreeting) >= Self.greetingCooldown
    }
}
