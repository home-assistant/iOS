import CoreLocation
import CoreMotion
import Foundation
import ObjectMapper

public enum LocationNames: String {
    case Home = "home"
    case NotHome = "not_home"
}

public struct WebhookUpdateLocation: ImmutableMappable {
    public var horizontalAccuracy: CLLocationAccuracy?
    public var battery: Int?
    public var location: CLLocationCoordinate2D?
    public var locationName: String?

    public var speed: CLLocationSpeed?
    public var altitude: CLLocationDistance?
    public var course: CLLocationDirection?
    public var verticalAccuracy: CLLocationAccuracy?

    // Not sent
    public var trigger: LocationUpdateTrigger

    public init(trigger: LocationUpdateTrigger) {
        self.trigger = trigger
        if let battery = Current.device.batteries().first {
            self.battery = battery.level
        }
    }

    public init(trigger: LocationUpdateTrigger, usingNameOf zone: RLMZone?) {
        self.init(trigger: trigger)
        self.locationName = zone?.deviceTrackerName ?? LocationNames.NotHome.rawValue
    }

    public init(trigger: LocationUpdateTrigger, location: CLLocation?, zone: RLMZone?) {
        self.init(trigger: trigger)

        let useLocation: Bool

        switch trigger {
        case .BeaconRegionExit, .BeaconRegionEnter:
            useLocation = false
        default:
            useLocation = true
        }

        if let location = location, useLocation {
            self.location = location.coordinate

            if location.speed > -1 {
                self.speed = location.speed
            }
            if location.course > -1 {
                self.course = location.course
            }
            if location.altitude > -1 {
                self.altitude = location.altitude
            }
            if location.verticalAccuracy > -1 {
                self.verticalAccuracy = location.verticalAccuracy
            }
            if location.horizontalAccuracy > -1 {
                self.horizontalAccuracy = location.horizontalAccuracy
            }
        } else if let zone = zone {
            if trigger != .BeaconRegionExit {
                self.location = zone.center
                self.horizontalAccuracy = zone.Radius
            }

            #if os(iOS)
            // https://github.com/home-assistant/iOS/issues/32
            if let currentSSID = Current.connectivity.currentWiFiSSID(), zone.SSIDTrigger.contains(currentSSID) {
                self.location = zone.center
                self.locationName = zone.Name
                return
            }
            #endif

            if zone.isHome {
                switch trigger {
                case .RegionEnter, .GPSRegionEnter, .BeaconRegionEnter:
                    self.locationName = LocationNames.Home.rawValue
                case .RegionExit, .GPSRegionExit:
                    self.locationName = LocationNames.NotHome.rawValue
                default:
                    break
                }
            } else {
                switch trigger {
                case .BeaconRegionEnter where !zone.isPassive:
                    self.locationName = zone.Name
                case .BeaconRegionExit:
                    break
                default:
                    break
                }
            }
        }
    }

    // Mappable
    public init(map: Map) throws {
        fatalError()
    }

    public func mapping(map: Map) {
        battery >>> map["battery"]
        location >>> (map["gps"], CLLocationCoordinate2DTransform())
        horizontalAccuracy >>> map["gps_accuracy"]
        locationName >>> map["location_name"]
        speed >>> map["speed"]
        altitude >>> map["altitude"]
        course >>> map["course"]
        verticalAccuracy >>> map["vertical_accuracy"]
    }
}
