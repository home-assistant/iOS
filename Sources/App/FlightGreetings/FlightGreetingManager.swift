import Foundation
import Shared
import UIKit

/// Coordinates the "have a great flight" greeting: runs flight detection when the app becomes
/// active or the web view loses connection, shows the greeting toast at most once per flight,
/// and caches detection results so repeated checks stay cheap.
@MainActor
final class FlightGreetingManager {
    static let shared = FlightGreetingManager()

    private static let toastID = "flight-greeting"
    private static let toastDuration: TimeInterval = 5
    /// One greeting per flight: suppress repeats until well after even a long-haul leg.
    private static let greetingCooldown: TimeInterval = 6 * 60 * 60
    private static let lastGreetingDateKey = "flightGreetingLastShownDate"
    /// How long a detection result stays valid before a caller triggers a fresh check. A positive
    /// stays valid for a while (the flight isn't ending soon); a negative retries sooner.
    private static let positiveDetectionValidity: TimeInterval = 10 * 60
    private static let negativeDetectionValidity: TimeInterval = 60

    private var cachedDetection: (isFlying: Bool, date: Date)?
    private var detectionTask: Task<Bool, Never>?

    func start() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                FlightGreetingManager.shared.greetIfFlying()
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
            if Date().timeIntervalSince(cachedDetection.date) < validity {
                return cachedDetection.isFlying
            }
        }
        if let detectionTask {
            return await detectionTask.value
        }
        let task = Task { await FlightDetector.isLikelyFlying() }
        detectionTask = task
        let isFlying = await task.value
        cachedDetection = (isFlying, Date())
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
        prefs.set(Date(), forKey: Self.lastGreetingDateKey)
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
        return Date().timeIntervalSince(lastGreeting) >= Self.greetingCooldown
    }
}
