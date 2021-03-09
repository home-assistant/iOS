import CoreLocation
import CoreMotion
import Foundation
import ObjectMapper

public enum LocationNames: String {
    case Home = "home"
    case NotHome = "not_home"
}

public class WebhookUpdateLocation: Mappable {
    public var HorizontalAccuracy: CLLocationAccuracy?
    public var Battery: Int?
    public var Location: CLLocationCoordinate2D?
    public var LocationName: String?

    public var Speed: CLLocationSpeed?
    public var Altitude: CLLocationDistance?
    public var Course: CLLocationDirection?
    public var VerticalAccuracy: CLLocationAccuracy?

    // Not sent
    public var Trigger: LocationUpdateTrigger = .Unknown

    init() {}

    public required init?(map: Map) {}

    public convenience init?(trigger: LocationUpdateTrigger, location: CLLocation?, zone: RLMZone?) {
        self.init()

        self.Trigger = trigger

        if let battery = Current.device.batteries().first {
            self.Battery = battery.level
        }

        let useLocation: Bool

        switch trigger {
        case .BeaconRegionExit, .BeaconRegionEnter:
            useLocation = false
        default:
            useLocation = true
        }

        if let location = location, useLocation {
            SetLocation(location: location)
        } else if let zone = zone {
            SetZone(zone: zone)
        } else {
            return nil
        }
    }

    public func SetZone(zone: RLMZone) {
        HorizontalAccuracy = zone.Radius
        Location = zone.center

        #if os(iOS)
        // https://github.com/home-assistant/home-assistant-iOS/issues/32
        if let currentSSID = Current.connectivity.currentWiFiSSID(), zone.SSIDTrigger.contains(currentSSID) {
            LocationName = zone.Name
            return
        }
        #endif

        if zone.isHome {
            switch Trigger {
            case .RegionEnter, .GPSRegionEnter, .BeaconRegionEnter:
                LocationName = LocationNames.Home.rawValue
            case .RegionExit, .GPSRegionExit:
                LocationName = LocationNames.NotHome.rawValue
            case .BeaconRegionExit:
                ClearLocation()
            default:
                break
            }
        } else {
            switch Trigger {
            case .BeaconRegionEnter where !zone.isPassive:
                LocationName = zone.Name
            case .BeaconRegionExit:
                ClearLocation()
            default:
                break
            }
        }
    }

    public func SetLocation(location: CLLocation) {
        Location = location.coordinate
        if location.speed > -1 {
            Speed = location.speed
        }
        if location.course > -1 {
            Course = location.course
        }
        if location.altitude > -1 {
            Altitude = location.altitude
        }
        if location.verticalAccuracy > -1 {
            VerticalAccuracy = location.verticalAccuracy
        }
        if location.horizontalAccuracy > -1 {
            HorizontalAccuracy = location.horizontalAccuracy
        }
    }

    public func ClearLocation() {
        HorizontalAccuracy = nil
        Location = nil
        Speed = nil
        Altitude = nil
        Course = nil
        VerticalAccuracy = nil
    }

    // Mappable
    public func mapping(map: Map) {
        Battery <- map["battery"]
        Location <- (map["gps"], CLLocationCoordinate2DTransform())
        HorizontalAccuracy <- map["gps_accuracy"]
        LocationName <- map["location_name"]

        Speed <- map["speed"]
        Altitude <- map["altitude"]
        Course <- map["course"]
        VerticalAccuracy <- map["vertical_accuracy"]
    }
}
