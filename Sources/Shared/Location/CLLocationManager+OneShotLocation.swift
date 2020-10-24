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
    static var desiredAccuracy: CLLocationAccuracy { 100.0 }
    static var invalidAccuracyThreshold: CLLocationAccuracy { 1500.0 }
    static var desiredAge: TimeInterval { 30.0 }
    static var invalidAgeThreshold: TimeInterval { 600.0 }

    enum Quality {
        case invalid
        case meh
        case perfect
    }

    let location: CLLocation
    let quality: Quality

    init(location: CLLocation) {
        self.location = location

        if location.coordinate.latitude == 0 || location.coordinate.longitude == 0 {
            // iOS 13.5? seems to occasionally report 0 lat/long, so ignore these locations
            Current.Log.error("Location \(location.coordinate) was super duper invalid")
            quality = .invalid
        } else {
            // now = 0 seconds ago
            // timestamp = 100 seconds ago
            // so age is the positive number of seconds since this update
            let age = Current.date().timeIntervalSince(location.timestamp)
            if location.horizontalAccuracy <= Self.desiredAccuracy && age <= Self.desiredAge {
                quality = .perfect
            } else if location.horizontalAccuracy > Self.invalidAccuracyThreshold || age > Self.invalidAgeThreshold {
                quality = .invalid
            } else {
                quality = .meh
            }
        }
    }

    var description: String {
        return "accuracy \(accuracy) from \(timestamp) quality \(quality)"
    }

    var accuracy: CLLocationAccuracy {
        return location.horizontalAccuracy
    }

    var timestamp: Date {
        return location.timestamp
    }

    static func == (lhs: PotentialLocation, rhs: PotentialLocation) -> Bool {
        return lhs.location == rhs.location
    }

    static func < (lhs: PotentialLocation, rhs: PotentialLocation) -> Bool {
        switch (lhs.quality, rhs.quality) {
        case (.perfect, .perfect):
            // both are 'perfect' so prefer the newer one
            return lhs.timestamp < rhs.timestamp
        case (.perfect, .meh),
             (.perfect, .invalid),
             (.meh, .invalid):
            // lhs is better, so it's 'greater'
            return false
        case (.meh, .perfect),
             (.invalid, .perfect),
             (.invalid, .meh):
            // rhs is better, so it's 'greater'
            return true
        case (.meh, .meh):
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
        case (.invalid, .invalid):
            // nobody cares
            return false
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

        Current.isPerformingSingleShotLocationQuery = true

        super.init()

        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.delegate = self

        selfRetain = self
        locationManager.startUpdatingLocation()
        _ = promise.ensure(on: workQueue) {
            locationManager.stopUpdatingLocation()
            locationManager.delegate = nil
            self.selfRetain = nil

            Current.isPerformingSingleShotLocationQuery = false
        }

        timeout.done(on: workQueue) { [weak self] in
            // we can be weak here because the alternative is that we're already resolved
            self?.checkPotentialLocations(outOfTime: true)
        }

        if let cachedLocation = locationManager.location {
            let potentialLocation = PotentialLocation(location: cachedLocation)
            potentialLocations.append(potentialLocation)
        }
    }

    private func checkPotentialLocations(outOfTime: Bool) {
        guard !promise.isResolved else {
            return
        }

        let bestLocation = potentialLocations.sorted().last

        if let bestLocation = bestLocation {
            switch bestLocation.quality {
            case .perfect:
                Current.Log.info("Got a perfect location!")
                seal.fulfill(bestLocation.location)
            case .invalid where outOfTime:
                Current.Log.error("Out of time with only invalid location!")
                seal.reject(OneShotError.outOfTime)
            case .meh where outOfTime:
                Current.Log.info("Out of time with a meh location")
                seal.fulfill(bestLocation.location)
            default:
                // keep looking
                break
            }
        } else if outOfTime {
            Current.Log.info("Out of time without any location!")
            seal.reject(OneShotError.outOfTime)
            return
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let updatedPotentialLocations = locations.map(PotentialLocation.init(location:))
        Current.Log.verbose("got potential locations: \(updatedPotentialLocations)")
        potentialLocations.append(contentsOf: updatedPotentialLocations)
        checkPotentialLocations(outOfTime: false)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let failError: Error

        if let clErr = error as? CLError {
            let realm = Current.realm()
            try? realm.write {
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
