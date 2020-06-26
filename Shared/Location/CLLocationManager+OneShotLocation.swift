import CoreLocation
import Foundation
import PromiseKit

public extension CLLocationManager {
    static func oneShotLocation(timeout: TimeInterval) -> Promise<CLLocation> {
        return OneShotLocationProxy(
            locationManager: CLLocationManager(),
            timeout: after(seconds: timeout)
        ).promise
    }
}

enum OneShotError: Error, Equatable {
    case clError(CLError)
    case outOfTime

    static func == (lhs: OneShotError, rhs: OneShotError) -> Bool {
        switch (lhs, rhs) {
        case (.clError(let lhsClError), .clError(let rhsClError)):
            return lhsClError.code == rhsClError.code
        case (.outOfTime, .outOfTime):
            return true
        default:
             return false
        }
    }
}

internal struct PotentialLocation: Comparable, CustomStringConvertible {
    let location: CLLocation

    static var desiredAccuracy: CLLocationAccuracy { 200.0 }
    static var desiredAge: TimeInterval { 30.0 }

    var description: String {
        return "accuracy \(accuracy) from \(timestamp)"
    }

    var accuracy: CLLocationAccuracy {
        return location.horizontalAccuracy
    }

    var timestamp: Date {
        return location.timestamp
    }

    var isPerfect: Bool {
        // now = 0 seconds ago
        // timestamp = 100 seconds ago
        // so age is the positive number of seconds since this update
        let age = Current.date().timeIntervalSince(timestamp)
        return accuracy < Self.desiredAccuracy && age <= Self.desiredAge
    }

    static func == (lhs: PotentialLocation, rhs: PotentialLocation) -> Bool {
        return lhs.location == rhs.location
    }

    static func < (lhs: PotentialLocation, rhs: PotentialLocation) -> Bool {
        switch (lhs.isPerfect, rhs.isPerfect) {
        case (true, true):
            // both are 'perfect' so prefer the newer one
            return lhs.timestamp < rhs.timestamp
        case (true, false):
            // lhs is better, so it's 'greater'
            return false
        case (false, true):
            // rhs is better, so it's 'greater'
            return true
        case (false, false):
            // neither are perfect, which is more recent?
            // if the time difference is a lot, prefer the more recent, even if less accurate
            if lhs.timestamp.timeIntervalSince(rhs.timestamp) > 60 {
                // lhs is more than a minute newer, prefer it
                return false
            } else if rhs.timestamp.timeIntervalSince(lhs.timestamp) > 60 {
                // rhs is more than a minute newer, prefer it
                return true
            } else {
                // prefer whichever is more accurate, since they're close in time to each other
                return lhs.accuracy > rhs.accuracy
            }
        }
    }
}

internal final class OneShotLocationProxy: NSObject, CLLocationManagerDelegate {
    let promise: Promise<CLLocation>
    private let seal: Resolver<CLLocation>
    private let locationManager: CLLocationManager
    private var selfRetain: OneShotLocationProxy?
    private var potentialLocations: [PotentialLocation] = []

    init(
        locationManager: CLLocationManager,
        timeout: Guarantee<Void>,
        workQueue: DispatchQueue? = nil
    ) {
        (self.promise, self.seal) = Promise<CLLocation>.pending()
        self.locationManager = locationManager

        super.init()

        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = kCLLocationAccuracyHundredMeters
        locationManager.delegate = self

        selfRetain = self
        locationManager.startUpdatingLocation()
        _ = promise.ensure(on: workQueue) {
            locationManager.stopUpdatingLocation()
            locationManager.delegate = nil
            self.selfRetain = nil
        }

        timeout.done(on: workQueue) { [weak self] in
            // we can be weak here because the alternative is that we're already resolved
            self?.checkPotentialLocations(outOfTime: true)
        }

        if let cachedLocation = locationManager.location {
            let potentialLocation = PotentialLocation(location: cachedLocation)
            potentialLocations.append(potentialLocation)

            let message = "Cached potential one-shot location of \(potentialLocation)"
            Current.clientEventStore.addEvent(ClientEvent(text: message, type: .locationUpdate))
        }
    }

    private func checkPotentialLocations(outOfTime: Bool) {
        guard !promise.isResolved else {
            return
        }

        let bestLocation = potentialLocations.sorted().last

        if let bestLocation = bestLocation {
            if bestLocation.isPerfect {
                Current.Log.info("Got a perfect location!")
                seal.fulfill(bestLocation.location)
            } else if outOfTime {
                Current.Log.info("Out of time, using \(bestLocation)")
                seal.fulfill(bestLocation.location)
            }
        } else if outOfTime {
            Current.Log.info("Out of time without any location!")
            seal.reject(OneShotError.outOfTime)
            return
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let updatedPotentialLocations = locations.map(PotentialLocation.init(location:))
        Current.Log.verbose("LocationManager: Got potential locations: \(potentialLocations)")
        potentialLocations.append(contentsOf: updatedPotentialLocations)
        checkPotentialLocations(outOfTime: false)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let failError: Error

        if let clErr = error as? CLError {
            let realm = Current.realm()
            // swiftlint:disable:next force_try
            try! realm.write {
                let locErr = LocationError(err: clErr)
                realm.add(locErr)
            }

            Current.Log.error("Received CLError: \(clErr)")
            failError = OneShotError.clError(clErr)
        } else {
            Current.Log.error("Received non-CLError when we only expected CLError: \(error)")
            failError = error
        }

        if potentialLocations.isEmpty {
            seal.reject(failError)
        } else {
            checkPotentialLocations(outOfTime: true)
        }
    }
}
