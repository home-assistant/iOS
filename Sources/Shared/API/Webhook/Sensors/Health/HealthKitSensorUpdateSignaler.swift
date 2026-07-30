#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// Turns HealthKit's background delivery into sensor updates.
///
/// Apple Health sensors used to only reach Home Assistant when something else asked for an update, so a
/// heart rate measured while the app was closed sat in HealthKit until the app was opened again. Observing
/// the enabled metrics means HealthKit wakes the app — relaunching it in the background if it has to — and
/// the new value goes out right then.
final class HealthKitSensorUpdateSignaler: SensorProviderUpdateSignaler {
    /// Window over which HealthKit callbacks coalesce into a single update. One workout lands samples for a
    /// dozen types at once and each of them calls back separately, so the window is what keeps that from
    /// becoming a dozen webhook requests. A `var` only so tests don't have to wait it out.
    static var signalDebounceInterval: TimeInterval = 5
    /// Shortest gap between two HealthKit-driven updates. Step counts and heart rates can change every few
    /// seconds while the phone is being worn, and every update sends the whole sensor payload, so the gap is
    /// what keeps background delivery from becoming a stream of webhook requests.
    static var minimumSignalInterval: TimeInterval = 30

    private let signal: () -> Void
    /// Guards everything below it.
    private let queue = DispatchQueue(label: AppConstants.BundleID + ".healthKitSensorUpdateSignaler")
    private var observedIdentifiers: Set<String>?
    private var isSignalPending = false
    private var lastSignalDate: Date?
    /// HealthKit's completion handlers for the changes waiting on the current window.
    private var pendingCompletions = [() -> Void]()

    init(signal: @escaping () -> Void) {
        self.signal = signal
    }

    /// Points HealthKit's observation at `metrics`, the Apple Health sensors that are currently switched on.
    /// Called on every sensor update, so re-observing an unchanged set has to stay free.
    func observe(metrics: [HealthKitMetric]) {
        queue.async { [self] in
            let identifiers = Set(metrics.map(\.identifier))
            guard identifiers != observedIdentifiers else { return }
            observedIdentifiers = identifiers

            Current.Log.info("observing \(identifiers.count) Apple Health metric(s) for background delivery")
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

        // A fixed window rather than one that slides on every callback, so a long burst of changes can't
        // keep pushing the update out past the time HealthKit is willing to wait.
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

        // Answering HealthKit only now means it keeps the app awake across the window above; from here the
        // sensor update carries its own background task.
        for completion in completions {
            completion()
        }
    }
}
#endif
