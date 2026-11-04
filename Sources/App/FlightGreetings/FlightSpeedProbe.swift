import CoreLocation
import Foundation
import Shared

/// Waits for the first location fix that carries a usable ground speed, or gives up.
///
/// `CLLocationManager.oneShotLocation` can't serve this: it optimizes for positional accuracy and
/// resolves on the first fix that is accurate and recent, which is frequently a fix whose `speed` is
/// -1 and therefore useless here. It also seeds itself from the manager's cached location, whose
/// speed describes wherever the device last was rather than how fast it is moving now.
///
/// A cabin has no network to assist the GPS either, so a cold fix there can take a minute. The
/// caller picks how long to wait.
///
/// Unlike `oneShotLocation` this deliberately leaves `Current.isPerformingSingleShotLocationQuery`
/// alone: raising that flag for the length of a cold fix would stop the zone manager from processing
/// anything for the whole window, which is a far worse trade than the extra location updates the
/// app's own manager sees while this runs. The long budget is only ever spent offline, where those
/// updates can't be delivered anyway.
@MainActor
final class FlightSpeedProbe: NSObject, CLLocationManagerDelegate {
    static func firstFixWithSpeed(timeout: TimeInterval) async -> CLLocation? {
        await FlightSpeedProbe().run(timeout: timeout)
    }

    private let locationManager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var timeoutWork: DispatchWorkItem?
    private var selfRetain: FlightSpeedProbe?

    private func run(timeout: TimeInterval) async -> CLLocation? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.selfRetain = self

            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()

            // GCD holds the deadline rather than `Task.sleep`: the timeout has to fire even when the
            // Swift concurrency thread pool is starved, which is one of the things it exists to bound.
            let work = DispatchWorkItem { [weak self] in
                Task { @MainActor in
                    self?.finish(with: nil)
                }
            }
            timeoutWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)
        }
    }

    private func finish(with location: CLLocation?) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutWork?.cancel()
        timeoutWork = nil
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
        selfRetain = nil
        continuation.resume(returning: location)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // A negative speed or speedAccuracy means the fix carries no velocity, which is common on the
        // first fixes of a cold start; keep waiting for one that does.
        guard let usable = locations.last(where: { $0.speed >= 0 && $0.speedAccuracy >= 0 }) else { return }
        Task { @MainActor [weak self] in
            self?.finish(with: usable)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Failures are routine while a GPS warms up with no network assistance, so let the timeout
        // decide rather than giving up on the first one.
        Current.Log.error("Flight speed probe received a location error: \(error)")
    }
}
