import CoreLocation
import Foundation
import PromiseKit

public extension CLLocationManager {
    static func oneShotLocation(timeout: TimeInterval) -> Promise<CLLocation> {
        OneShotLocationProxy(
            locationManager: CLLocationManager(),
            timeout: after(seconds: timeout)
        ).promise
    }
}

enum OneShotError: Error, Equatable, LocalizedError, CustomNSError {
    case clError(CLError)
    case outOfTime

    var errorDescription: String? {
        switch self {
        case let .clError(error):
            return error.localizedDescription
        case .outOfTime:
            return L10n.ClError.Description.locationUnknown
        }
    }

    static var errorDomain: String {
        "OneShotError"
    }

    var errorCode: Int {
        switch self {
        case let .clError(error): return 1000 + error.code.rawValue
        case .outOfTime: return 1
        }
    }

    static func == (lhs: OneShotError, rhs: OneShotError) -> Bool {
        switch (lhs, rhs) {
        case let (.clError(lhsClError), .clError(rhsClError)):
            return lhsClError.code == rhsClError.code
        case (.outOfTime, .outOfTime):
            return true
        default:
            return false
        }
    }
}

internal struct PotentialLocation: Comparable, CustomStringConvertible {
    static func desiredAccuracy(for accuracy: CLAccuracyAuthorization) -> CLLocationAccuracy {
        switch accuracy {
        case .fullAccuracy: return 100.0
        case .reducedAccuracy: return 3000.0
        @unknown default: return 100.0
        }
    }

    static func invalidAccuracyThreshold(for accuracy: CLAccuracyAuthorization) -> CLLocationAccuracy {
        switch accuracy {
        case .fullAccuracy: return 1500.0
        case .reducedAccuracy: return .greatestFiniteMagnitude
        @unknown default: return .greatestFiniteMagnitude
        }
    }

    static var desiredAge: TimeInterval { 30.0 }
    static var invalidAgeThreshold: TimeInterval { 600.0 }

    enum Quality {
        case invalid
        case meh
        case perfect
    }

    let location: CLLocation
    let quality: Quality

    init(location: CLLocation, accuracyAuthorization: CLAccuracyAuthorization) {
        do {
            self.location = try location.sanitized()
        } catch {
            Current.Log.error("Location \(location.coordinate) couldn't be sanitized: \(error)")
            self.quality = .invalid
            self.location = location
            return
        }

        func isBadCoordinateValue(_ value: Double) -> Bool {
            // this is within 110µm of 0.0 latitude/longitude and is very unlikely to really happen
            (value >= 0 && value <= 0.000000001) || (value >= -0.000000001 && value <= 0)
        }

        if isBadCoordinateValue(location.coordinate.latitude) || isBadCoordinateValue(location.coordinate.longitude) {
            // iOS 13.5? seems to occasionally report 0 lat/long, so ignore these locations
            // iOS 15? seems to occasionally report ``9.368162246e-315 (or similar small values), so ignore these too
            Current.Log.error("Location \(location.coordinate) was super duper invalid")
            self.quality = .invalid
        } else {
            // now = 0 seconds ago
            // timestamp = 100 seconds ago
            // so age is the positive number of seconds since this update
            let age = Current.date().timeIntervalSince(location.timestamp)
            let desiredAccuracy = Self.desiredAccuracy(for: accuracyAuthorization)
            let invalidAccuracyThreshold = Self.invalidAccuracyThreshold(for: accuracyAuthorization)

            if location.horizontalAccuracy <= desiredAccuracy && age <= Self.desiredAge {
                self.quality = .perfect
            } else if location.horizontalAccuracy > invalidAccuracyThreshold || age > Self.invalidAgeThreshold {
                self.quality = .invalid
            } else {
                self.quality = .meh
            }
        }
    }

    var description: String {
        "coordinate \(location.coordinate) accuracy \(accuracy) from \(timestamp) quality \(quality)"
    }

    var accuracy: CLLocationAccuracy {
        location.horizontalAccuracy
    }

    var timestamp: Date {
        location.timestamp
    }

    static func == (lhs: PotentialLocation, rhs: PotentialLocation) -> Bool {
        lhs.location == rhs.location
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
    private(set) var promise: Promise<CLLocation>
    private let seal: Resolver<CLLocation>
    private let locationManager: CLLocationManager
    private var selfRetain: OneShotLocationProxy?
    private var potentialLocations: [PotentialLocation] = [] {
        didSet {
            precondition(Thread.isMainThread)
        }
    }

    init(
        locationManager: CLLocationManager,
        timeout: Guarantee<Void>
    ) {
        precondition(Thread.isMainThread)

        (self.promise, self.seal) = Promise<CLLocation>.pending()
        self.locationManager = locationManager

        Current.isPerformingSingleShotLocationQuery = true

        super.init()

        locationManager.allowsBackgroundLocationUpdates = !Current.isAppExtension
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.delegate = self

        self.selfRetain = self
        locationManager.startUpdatingLocation()
        self.promise = promise.ensure {
            locationManager.stopUpdatingLocation()
            locationManager.delegate = nil
            self.selfRetain = nil

            Current.isPerformingSingleShotLocationQuery = false
        }

        timeout.done { [weak self] in
            // we can be weak here because the alternative is that we're already resolved
            self?.checkPotentialLocations(outOfTime: true)
        }

        if let cachedLocation = locationManager.location {
            let authorization: CLAccuracyAuthorization

            if #available(iOS 14, watchOS 7, *) {
                authorization = locationManager.accuracyAuthorization
            } else {
                authorization = .fullAccuracy
            }

            let potentialLocation = PotentialLocation(location: cachedLocation, accuracyAuthorization: authorization)
            potentialLocations.append(potentialLocation)
        }
    }

    private func checkPotentialLocations(outOfTime: Bool) {
        precondition(Thread.isMainThread)

        guard !promise.isResolved else {
            return
        }

        let bestLocation = potentialLocations.sorted().last

        if let bestLocation = bestLocation {
            switch bestLocation.quality {
            case .perfect:
                Current.Log.info("Got a perfect location!")
                seal.fulfill(bestLocation.location)
            case .invalid:
                if outOfTime {
                    Current.Log.error("Out of time with only invalid location!")
                    seal.reject(OneShotError.outOfTime)
                }
            case .meh:
                if outOfTime {
                    Current.Log.info("Out of time with a meh location")
                    seal.fulfill(bestLocation.location)
                }
            }
        } else if outOfTime {
            Current.Log.info("Out of time without any location!")
            seal.reject(OneShotError.outOfTime)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        precondition(Thread.isMainThread)

        let authorization: CLAccuracyAuthorization

        if #available(iOS 14, watchOS 7, *) {
            authorization = manager.accuracyAuthorization
        } else {
            authorization = .fullAccuracy
        }

        let updatedPotentialLocations = locations.map {
            PotentialLocation(location: $0, accuracyAuthorization: authorization)
        }
        Current.Log.verbose("got raw locations \(locations) and turned into potential: \(updatedPotentialLocations)")
        potentialLocations.append(contentsOf: updatedPotentialLocations)
        checkPotentialLocations(outOfTime: false)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        precondition(Thread.isMainThread)

        let failError: Error

        if let clErr = error as? CLError {
            let realm = Current.realm()
            realm.reentrantWrite {
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
