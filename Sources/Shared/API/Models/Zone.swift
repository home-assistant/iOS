import CoreLocation
import Foundation
import ObjectMapper

public class Zone: Entity {
    @objc public dynamic var Latitude: Double = 0.0
    @objc public dynamic var Longitude: Double = 0.0
    @objc public dynamic var Radius: Double = 0.0
    @objc public dynamic var TrackingEnabled = true
    @objc public dynamic var enterNotification = true
    @objc public dynamic var exitNotification = true
    @objc public dynamic var isPassive = false

    // Beacons
    @objc public dynamic var UUID: String?
    public var Major: Int?
    public var Minor: Int?

    // SSID
    public var SSIDTrigger: [String]?
    public var SSIDFilter: [String]?

    override public func mapping(map: Map) {
        super.mapping(map: map)

        Latitude <- map["attributes.latitude"]
        Longitude <- map["attributes.longitude"]
        Radius <- map["attributes.radius"]
        TrackingEnabled <- map["attributes.track_ios"]
        UUID <- map["attributes.beacon.uuid"]
        Major <- map["attributes.beacon.major"]
        Minor <- map["attributes.beacon.minor"]
        SSIDTrigger <- map["attributes.ssid_trigger"]
        SSIDFilter <- map["attributes.ssid_filter"]
        isPassive <- map["attributes.passive"]
    }

    public func locationCoordinates() -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: CLLocationDegrees(Latitude),
            longitude: CLLocationDegrees(Longitude)
        )
    }

    public func location() -> CLLocation {
        CLLocation(
            coordinate: locationCoordinates(),
            altitude: 0,
            horizontalAccuracy: Radius,
            verticalAccuracy: -1,
            timestamp: Date()
        )
    }
}
