import Foundation
@testable import HomeAssistant
@testable import Shared
import XCTest

final class CabinPressureMonitorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Sustained change

    func testCabinClimbIsASustainedChange() throws {
        // Pressurization takes the cabin down about 1.2 kPa every minute, minute after minute.
        let samples = makeSamples(startPressureKpa: 101.3, kpaPerMinute: -1.2)

        let rate = try XCTUnwrap(CabinPressureMonitor.sustainedChangeKpaPerMinute(in: samples, now: now))
        XCTAssertEqual(rate, -1.2, accuracy: 0.2)
    }

    func testCabinDescentIsASustainedChange() throws {
        let samples = makeSamples(startPressureKpa: 78.0, kpaPerMinute: 0.9)

        let rate = try XCTUnwrap(CabinPressureMonitor.sustainedChangeKpaPerMinute(in: samples, now: now))
        XCTAssertEqual(rate, 0.9, accuracy: 0.2)
    }

    func testElevatorRideIsNotASustainedChange() {
        // A skyscraper elevator moves as much pressure as a climb but is over in under a minute, so
        // it lands in one bucket instead of filling the window.
        var samples = makeSamples(startPressureKpa: 101.3, kpaPerMinute: 0)
        samples = samples.map { sample in
            let secondsAgo = now.timeIntervalSince(sample.date)
            guard secondsAgo <= 160 else { return sample }
            let progress = min(1, max(0, (160 - secondsAgo) / 40))
            return CabinPressureSample(date: sample.date, pressureKpa: sample.pressureKpa - 3.5 * progress)
        }

        XCTAssertNil(CabinPressureMonitor.sustainedChangeKpaPerMinute(in: samples, now: now))
    }

    func testSteadyPressureIsNotASustainedChange() {
        let samples = makeSamples(startPressureKpa: 101.3, kpaPerMinute: 0, noiseKpa: 0.05)

        XCTAssertNil(CabinPressureMonitor.sustainedChangeKpaPerMinute(in: samples, now: now))
    }

    func testSlowDriftIsNotASustainedChange() {
        // Weather moves pressure, but nowhere near fast enough to clear the per-minute floor.
        let samples = makeSamples(startPressureKpa: 101.3, kpaPerMinute: -0.05)

        XCTAssertNil(CabinPressureMonitor.sustainedChangeKpaPerMinute(in: samples, now: now))
    }

    func testTooShortAWindowIsNotASustainedChange() {
        let samples = makeSamples(startPressureKpa: 101.3, kpaPerMinute: -1.2, spanning: 90)

        XCTAssertNil(CabinPressureMonitor.sustainedChangeKpaPerMinute(in: samples, now: now))
    }

    // MARK: - Evidence

    func testNoSamplesIsInsufficientData() {
        XCTAssertEqual(
            CabinPressureMonitor.evidence(samples: [], baseline: baseline(kpa: 101.3), now: now),
            .insufficientData
        )
    }

    func testCabinCruisePressureFarBelowBaselineIsLowPressure() {
        let samples = makeSamples(startPressureKpa: 78.0, kpaPerMinute: 0)

        let evidence = CabinPressureMonitor.evidence(
            samples: samples,
            baseline: baseline(kpa: 101.3),
            now: now
        )
        guard case let .lowPressure(kpa, belowBaselineKpa) = evidence else {
            XCTFail("Expected low pressure, got \(evidence)")
            return
        }
        XCTAssertEqual(kpa, 78.0, accuracy: 0.01)
        XCTAssertEqual(belowBaselineKpa, 23.3, accuracy: 0.01)
    }

    func testCabinCruisePressureWithoutABaselineIsInconclusive() {
        // Nothing to compare against, so a device that simply lives high up never reads as flying.
        let samples = makeSamples(startPressureKpa: 78.0, kpaPerMinute: 0)

        XCTAssertEqual(
            CabinPressureMonitor.evidence(samples: samples, baseline: nil, now: now),
            .inconclusive
        )
    }

    func testStaleBaselineIsIgnored() {
        let samples = makeSamples(startPressureKpa: 78.0, kpaPerMinute: 0)
        let stale = CabinPressureSample(
            date: now.addingTimeInterval(-CabinPressureMonitor.baselineValidity - 60),
            pressureKpa: 101.3
        )

        XCTAssertEqual(
            CabinPressureMonitor.evidence(samples: samples, baseline: stale, now: now),
            .inconclusive
        )
    }

    func testHighElevationGroundDoesNotClearTheBaselineDrop() {
        // Denver sits near 83.5 kPa, so a cabin is only ~5 kPa below its baseline — under the margin.
        let samples = makeSamples(startPressureKpa: 78.0, kpaPerMinute: 0)

        XCTAssertEqual(
            CabinPressureMonitor.evidence(samples: samples, baseline: baseline(kpa: 83.5), now: now),
            .inconclusive
        )
    }

    func testPressureAboveTheCabinCeilingIsInconclusive() {
        // 1,100 m of ground elevation is a big drop from a sea-level baseline but is not a cabin.
        let samples = makeSamples(startPressureKpa: 89.0, kpaPerMinute: 0)

        XCTAssertEqual(
            CabinPressureMonitor.evidence(samples: samples, baseline: baseline(kpa: 101.3), now: now),
            .inconclusive
        )
    }

    func testSustainedChangeIsReportedWithoutABaseline() {
        // The climb out of a high-elevation airport never clears the baseline drop, so the trend is
        // the only thing that can catch it.
        let samples = makeSamples(startPressureKpa: 101.3, kpaPerMinute: -1.2)

        let evidence = CabinPressureMonitor.evidence(samples: samples, baseline: nil, now: now)
        guard case let .sustainedChange(kpaPerMinute) = evidence else {
            XCTFail("Expected a sustained change, got \(evidence)")
            return
        }
        XCTAssertEqual(kpaPerMinute, -1.2, accuracy: 0.2)
    }

    func testOnlyPositiveEvidenceIndicatesFlight() {
        XCTAssertFalse(CabinPressureEvidence.insufficientData.indicatesFlight)
        XCTAssertFalse(CabinPressureEvidence.inconclusive.indicatesFlight)
        XCTAssertTrue(CabinPressureEvidence.sustainedChange(kpaPerMinute: -1.2).indicatesFlight)
        XCTAssertTrue(CabinPressureEvidence.lowPressure(kpa: 78, belowBaselineKpa: 23).indicatesFlight)
    }

    // MARK: - Helpers

    private func baseline(kpa: Double) -> CabinPressureSample {
        CabinPressureSample(date: now.addingTimeInterval(-60 * 60), pressureKpa: kpa)
    }

    /// A window of readings ending at `now`, five seconds apart, changing at a fixed rate.
    private func makeSamples(
        startPressureKpa: Double,
        kpaPerMinute: Double,
        spanning span: TimeInterval = CabinPressureMonitor.trendWindow,
        noiseKpa: Double = 0
    ) -> [CabinPressureSample] {
        let interval: TimeInterval = 5
        let count = Int(span / interval)
        return (0 ... count).map { step in
            let secondsIn = Double(step) * interval
            // A deterministic wobble, so a "steady" window still isn't perfectly flat.
            let noise = noiseKpa * (step.isMultiple(of: 2) ? 1 : -1)
            return CabinPressureSample(
                date: now.addingTimeInterval(-span + secondsIn),
                pressureKpa: startPressureKpa + kpaPerMinute * (secondsIn / 60) + noise
            )
        }
    }
}
