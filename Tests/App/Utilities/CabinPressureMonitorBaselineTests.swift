import CoreMotion
import Foundation
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// The ground baseline the cabin pressure rule compares against: readings taken with a network record
/// the highest recent pressure, never one at cabin pressure or one taken offline, and without a
/// barometer nothing is observed at all.
///
/// `.sharedState`: the baseline lives in the app group preferences. Each test also gets its own
/// environment, whose clock, network and barometer it controls.
@Suite(.sharedState)
struct CabinPressureMonitorBaselineTests {
    private final class Feed {
        var handler: CMAltitudeHandler?
        var now = Date(timeIntervalSince1970: 1_700_000_000)

        func read(kpa: Double, after seconds: TimeInterval = 60) {
            now = now.addingTimeInterval(seconds)
            handler?(PressureReading(kpa: kpa), nil)
        }
    }

    private final class PressureReading: CMAltitudeData {
        private let kpa: NSNumber

        init(kpa: Double) {
            self.kpa = NSNumber(value: kpa)
            super.init()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override var pressure: NSNumber { kpa }
        override var relativeAltitude: NSNumber { NSNumber(value: 0) }
    }

    private func preservingBaseline(_ body: () throws -> Void) rethrows {
        let keys = [CabinPressureMonitor.baselinePressureKey, CabinPressureMonitor.baselineDateKey]
        let previous = keys.map { prefs.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, previous) {
                prefs.set(value, forKey: key)
            }
        }
        for key in keys {
            prefs.removeObject(forKey: key)
        }
        try body()
    }

    @Test(.isolatedEnvironment)
    func readingsWithANetworkRecordTheGroundBaseline() {
        preservingBaseline {
            let feed = Feed()
            var networkType = NetworkType.wifi
            Current.date = { feed.now }
            Current.connectivity.simpleNetworkType = { networkType }
            Current.barometer.isAvailable = { true }
            Current.barometer.isAuthorized = { true }
            Current.barometer.startUpdatesOnQueueHandler = { _, handler in feed.handler = handler }
            Current.barometer.stopUpdates = { feed.handler = nil }
            Current.barometerObserver = BarometerObserver()

            let monitor = CabinPressureMonitor()
            monitor.start { _ in }
            #expect(monitor.isObserving)

            feed.read(kpa: 101.3)
            #expect(monitor.groundBaseline?.pressureKpa == 101.3)
            // A lower reading while the baseline is fresh keeps it; a higher one replaces it.
            feed.read(kpa: 100.9)
            #expect(monitor.groundBaseline?.pressureKpa == 101.3)
            feed.read(kpa: 101.8)
            #expect(monitor.groundBaseline?.pressureKpa == 101.8)
            // Cabin pressure never becomes the baseline.
            feed.read(kpa: 78)
            #expect(monitor.groundBaseline?.pressureKpa == 101.8)
            // Offline the device could be airborne, so nothing is recorded.
            networkType = .noConnection
            feed.read(kpa: 102.5)
            #expect(monitor.groundBaseline?.pressureKpa == 101.8)
            // A stale baseline is replaced even by a lower reading.
            networkType = .cellular
            feed.read(kpa: 100.2, after: 3 * 24 * 60 * 60)
            #expect(monitor.groundBaseline?.pressureKpa == 100.2)

            monitor.stop()
            #expect(!monitor.isObserving)
        }
    }

    @Test(.isolatedEnvironment)
    func withoutABarometerNothingIsObserved() {
        Current.barometer.isAvailable = { false }
        Current.barometerObserver = BarometerObserver()
        let monitor = CabinPressureMonitor()
        monitor.start { _ in }
        // A second foreground pass retries quietly.
        monitor.start { _ in }
        #expect(!monitor.isObserving)
        monitor.stop()
    }
}
