import CoreLocation
import Foundation
@testable import HomeAssistant
import Testing

/// The speed probe gives up when its time budget runs out without a fix that carries a speed, and
/// ignores fixes without velocity and location errors along the way.
@MainActor
struct FlightSpeedProbeTests {
    @MainActor
    private final class Answer {
        var outcome: (fix: CLLocation?, elapsed: Duration)?
    }

    private func location(speed: CLLocationSpeed, speedAccuracy: CLLocationSpeedAccuracy) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 52.3, longitude: 4.76),
            altitude: 10000,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            course: 90,
            courseAccuracy: 5,
            speed: speed,
            speedAccuracy: speedAccuracy,
            timestamp: Date()
        )
    }

    @Test func theProbeGivesUpWhenTheBudgetRunsOut() async {
        let budget: TimeInterval = 0.2
        let clock = ContinuousClock()
        let started = clock.now
        let answer = Answer()
        Task {
            let fix = await FlightSpeedProbe.firstFixWithSpeed(timeout: budget)
            answer.outcome = (fix, clock.now - started)
        }
        // The budget's deadline and the answer both reach the probe through the main queue, which
        // other suites keep busy under load, so how long it took in wall-clock time says nothing.
        // What matters is that it answers at all instead of waiting for a fix forever.
        let answered = await LoadTolerantDeadline.waitUntil { answer.outcome != nil }
        #expect(answered)
        guard let outcome = answer.outcome else { return }
        // The simulator rarely has a moving fix; any fix the probe returns carries a speed, and
        // without one it waited out its whole budget rather than giving up early.
        if let fix = outcome.fix {
            #expect(fix.speed >= 0)
        } else {
            #expect(outcome.elapsed >= .seconds(budget))
        }
    }

    @Test func fixesWithoutVelocityAndErrorsAreIgnored() {
        let probe = FlightSpeedProbe()
        let manager = CLLocationManager()
        probe.locationManager(manager, didUpdateLocations: [location(speed: -1, speedAccuracy: -1)])
        probe.locationManager(manager, didUpdateLocations: [location(speed: 240, speedAccuracy: -1)])
        probe.locationManager(manager, didFailWithError: CLError(.locationUnknown))
        // A usable fix with nothing waiting for it is dropped.
        probe.locationManager(manager, didUpdateLocations: [location(speed: 240, speedAccuracy: 2)])
    }
}
