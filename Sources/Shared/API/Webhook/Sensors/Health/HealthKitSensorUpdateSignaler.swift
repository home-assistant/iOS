#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// Asks for a sensor update whenever HealthKit reports new samples for an enabled Apple Health metric,
/// including when iOS wakes or relaunches the app in the background to deliver them.
final class HealthKitSensorUpdateSignaler: SensorProviderUpdateSignaler {
    /// Window over which HealthKit callbacks coalesce into one update; a workout lands samples for a dozen
    /// types at once. A `var` only so tests don't have to wait it out.
    static var signalDebounceInterval: TimeInterval = 5
    /// Shortest gap between two HealthKit-driven updates, so a metric that changes every few seconds can't
    /// become a stream of webhook requests.
    static var minimumSignalInterval: TimeInterval = 30

    private let signal: () -> Void
    /// Guards everything below it.
    private let queue = DispatchQueue(label: AppConstants.BundleID + ".healthKitSensorUpdateSignaler")
    private var observedUniqueIDs: Set<String>?
    private var isSignalPending = false
    private var lastSignalDate: Date?
    private var pendingCompletions = [() -> Void]()

    init(signal: @escaping () -> Void) {
        self.signal = signal
    }

    /// Called on every sensor update, so re-observing an unchanged set has to stay free.
    ///
    /// Compared by metric rather than by the type each one reads: several metrics can share a type
    /// (every sleep metric does) while others, like the activity rings, are observed through types
    /// of their own that their shared identifier doesn't name. The service dedupes the types.
    func observe(metrics: [HealthKitMetric]) {
        queue.async { [self] in
            let uniqueIDs = Set(metrics.map(\.uniqueID))
            guard uniqueIDs != observedUniqueIDs else { return }
            observedUniqueIDs = uniqueIDs

            Current.Log.info("observing \(uniqueIDs.count) Apple Health metric(s) for background delivery")
            Current.healthKitService.setObservedMetrics(metrics) { [weak self] completion in
                guard let self else {
                    completion()
                    return
                }
                queue.async { self.enqueue(completion: completion) }
            }
        }
    }

    /// Must run on `queue`.
    private func enqueue(completion: @escaping () -> Void) {
        pendingCompletions.append(completion)

        // A fixed window rather than one sliding on every callback, so a burst can't push the update out
        // past the time HealthKit is willing to wait.
        guard !isSignalPending else { return }
        isSignalPending = true
        queue.asyncAfter(deadline: .now() + delayUntilNextSignal()) { [weak self] in
            self?.fireSignal()
        }
    }

    /// Must run on `queue`.
    private func delayUntilNextSignal() -> TimeInterval {
        guard let lastSignalDate else {
            return Self.signalDebounceInterval
        }

        let remaining = Self.minimumSignalInterval - Current.date().timeIntervalSince(lastSignalDate)
        // Clamped so a clock that jumped backwards can't push the update out indefinitely.
        return max(Self.signalDebounceInterval, min(Self.minimumSignalInterval, remaining))
    }

    /// Must run on `queue`.
    private func fireSignal() {
        let completions = pendingCompletions
        pendingCompletions = []
        isSignalPending = false
        lastSignalDate = Current.date()

        signal()

        // Answering HealthKit only now is what keeps the app awake across the window above.
        for completion in completions {
            completion()
        }
    }
}
#endif
