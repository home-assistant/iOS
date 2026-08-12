import CoreMotion
import Foundation
import Shared

/// Watches cabin air pressure to decide whether the device is inside a pressurized aircraft.
///
/// This is the only flight signal that survives with neither connectivity nor a GPS fix: the
/// barometer reads the air in the cabin, so it works in a middle seat with the phone in a pocket.
/// Airliners hold the cabin between 6,000 and 8,000 ft, which is 75–81 kPa against 101 kPa at sea
/// level, and they take ten minutes or more to get there.
///
/// Readings arrive through `Current.barometerObserver` so the pressure sensor keeps working while
/// this is running.
final class CabinPressureMonitor {
    static let shared = CabinPressureMonitor()

    private static let subscriberID = "cabin-pressure-monitor"

    /// Ground level somewhere on Earth reaches this low — Bogotá sits near 74 kPa — so a reading
    /// under the ceiling is evidence of a flight only alongside the device's own ground baseline.
    static let cabinPressureCeilingKpa: Double = 82
    /// Sea-level ground to cabin cruise is a drop of roughly 23 kPa, and no weather system moves
    /// pressure by more than about 3 kPa, so this margin can't come from weather or sensor drift.
    static let baselineDropKpa: Double = 8
    /// Pressurization moves the cabin by 0.9–1.5 kPa/min for ten minutes or more. Requiring the
    /// change to repeat across separate minutes is what separates it from an elevator ride, which
    /// moves as much pressure but only for seconds.
    static let trendWindow: TimeInterval = 5 * 60
    static let trendBucket: TimeInterval = 60
    static let trendBucketMinimumChangeKpa: Double = 0.35
    static let trendRequiredBuckets = 4
    /// Past this the device has likely moved to a different elevation, making the baseline unusable.
    static let baselineValidity: TimeInterval = 48 * 60 * 60

    private static let baselinePressureKey = "cabinPressureGroundBaselineKpa"
    private static let baselineDateKey = "cabinPressureGroundBaselineDate"

    private let lock = NSLock()
    private var samples: [CabinPressureSample] = []
    private var didIndicateFlight = false
    private var didLogUnavailable = false
    private var evidenceDidChange: ((CabinPressureEvidence) -> Void)?

    /// What the current window of readings says. `.insufficientData` while nothing is being observed.
    var evidence: CabinPressureEvidence {
        lock.lock()
        let currentSamples = samples
        lock.unlock()
        return Self.evidence(samples: currentSamples, baseline: groundBaseline, now: Current.date())
    }

    var isObserving: Bool {
        Current.barometerObserver.hasSubscriber(id: Self.subscriberID)
    }

    /// The highest pressure recently seen while the device had a network, which stands in for "the
    /// air where this device lives". Nil until one has been recorded.
    var groundBaseline: CabinPressureSample? {
        // The two keys are always written together, so the date doubles as the presence check.
        guard let date = prefs.object(forKey: Self.baselineDateKey) as? Date else { return nil }
        return CabinPressureSample(date: date, pressureKpa: prefs.double(forKey: Self.baselinePressureKey))
    }

    /// Starts feeding the rolling window, calling `onEvidenceChange` when the verdict flips between
    /// suggesting a flight and not.
    ///
    /// Does nothing when there is no barometer or Motion & Fitness access hasn't been granted.
    /// Authorization is only ever checked, never requested, so this cannot raise a permission prompt.
    func start(onEvidenceChange: @escaping (CabinPressureEvidence) -> Void) {
        lock.lock()
        evidenceDidChange = onEvidenceChange
        lock.unlock()

        guard !isObserving else { return }

        let started = Current.barometerObserver.addSubscriber(id: Self.subscriberID) { [weak self] data, _ in
            guard let data else { return }
            self?.record(pressureKpa: data.pressure.doubleValue)
        }
        guard !started else { return }
        // Every foreground pass retries, so log the reason once rather than on each attempt.
        lock.lock()
        let shouldLog = !didLogUnavailable
        didLogUnavailable = true
        lock.unlock()
        if shouldLog {
            Current.Log.info("Cabin pressure monitoring unavailable: no barometer or no motion access")
        }
    }

    func stop() {
        Current.barometerObserver.removeSubscriber(id: Self.subscriberID)
        lock.lock()
        samples.removeAll()
        didIndicateFlight = false
        evidenceDidChange = nil
        lock.unlock()
    }

    private func record(pressureKpa: Double) {
        let now = Current.date()
        updateGroundBaselineIfNeeded(pressureKpa: pressureKpa, now: now)

        lock.lock()
        samples.removeAll { now.timeIntervalSince($0.date) > Self.trendWindow }
        samples.append(CabinPressureSample(date: now, pressureKpa: pressureKpa))
        let currentSamples = samples
        lock.unlock()

        let evidence = Self.evidence(samples: currentSamples, baseline: groundBaseline, now: now)

        lock.lock()
        // Only the verdict is worth reporting: `sustainedChange` carries a rate that moves with every
        // reading, and comparing the whole value would fire a callback a second.
        let flipped = evidence.indicatesFlight != didIndicateFlight
        didIndicateFlight = evidence.indicatesFlight
        let notify = flipped ? evidenceDidChange : nil
        lock.unlock()

        if let notify {
            Current.Log.info("Cabin pressure evidence changed to \(evidence)")
            notify(evidence)
        }
    }

    private func updateGroundBaselineIfNeeded(pressureKpa: Double, now: Date) {
        // A reading at or below cabin cruise pressure must never become the baseline: recording one
        // mid-flight would erase the very drop the low-pressure rule looks for. It also means a
        // device that lives above the ceiling never gets a baseline, so that rule stays silent there
        // rather than firing on every reading.
        guard pressureKpa > Self.cabinPressureCeilingKpa else { return }
        // With no network the device could be airborne, so the reading isn't trustworthy as ground.
        guard Current.connectivity.simpleNetworkType() != .noConnection else { return }

        if let existing = groundBaseline,
           now.timeIntervalSince(existing.date) <= Self.baselineValidity,
           pressureKpa <= existing.pressureKpa {
            return
        }

        prefs.set(pressureKpa, forKey: Self.baselinePressureKey)
        prefs.set(now, forKey: Self.baselineDateKey)
    }

    static func evidence(
        samples: [CabinPressureSample],
        baseline: CabinPressureSample?,
        now: Date
    ) -> CabinPressureEvidence {
        guard let latest = samples.last else { return .insufficientData }

        if let rate = sustainedChangeKpaPerMinute(in: samples, now: now) {
            return .sustainedChange(kpaPerMinute: rate)
        }

        if latest.pressureKpa <= cabinPressureCeilingKpa,
           let baseline,
           now.timeIntervalSince(baseline.date) <= baselineValidity,
           baseline.pressureKpa - latest.pressureKpa >= baselineDropKpa {
            return .lowPressure(
                kpa: latest.pressureKpa,
                belowBaselineKpa: baseline.pressureKpa - latest.pressureKpa
            )
        }

        return .inconclusive
    }

    /// The mean per-minute pressure change, but only when it holds across most of the window rather
    /// than in one burst. A skyscraper elevator moves 3 kPa in forty seconds and then stops, which
    /// clears any threshold on total change but fills a single bucket; a cabin fills all of them.
    static func sustainedChangeKpaPerMinute(in samples: [CabinPressureSample], now: Date) -> Double? {
        guard let oldest = samples.first,
              now.timeIntervalSince(oldest.date) >= trendWindow - trendBucket else {
            return nil
        }

        let bucketCount = Int(trendWindow / trendBucket)
        var changes = [Double]()
        for index in 0 ..< bucketCount {
            let start = now.addingTimeInterval(-trendWindow + Double(index) * trendBucket)
            let end = start.addingTimeInterval(trendBucket)
            // Both ends are inclusive on purpose, so consecutive buckets share the reading on their
            // boundary: each one then spans a whole minute instead of stopping at the last reading
            // before it, which would make every bucket read low by one sampling interval.
            let bucket = samples.filter { $0.date >= start && $0.date <= end }
            // `CMAltimeter` reports on change rather than at a fixed rate, so a minute can arrive
            // with a single reading. That measures nothing, and recording it as a zero change would
            // pass it off as a flat minute.
            guard bucket.count >= 2, let first = bucket.first, let last = bucket.last else { continue }
            changes.append(last.pressureKpa - first.pressureKpa)
        }

        let rising = changes.filter { $0 >= trendBucketMinimumChangeKpa }
        let falling = changes.filter { $0 <= -trendBucketMinimumChangeKpa }
        let dominant = rising.count >= falling.count ? rising : falling
        guard dominant.count >= trendRequiredBuckets else { return nil }

        return dominant.reduce(0, +) / (Double(dominant.count) * trendBucket / 60)
    }
}
