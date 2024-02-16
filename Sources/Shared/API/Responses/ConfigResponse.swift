import Foundation
import ObjectMapper

public class ConfigResponse: Mappable {
    public var Components: [String] = []
    public var Version: String = ""

    public var TemperatureUnit: String?
    public var LengthUnit: String?
    public var MassUnit: String?
    public var PressureUnit: String?
    public var VolumeUnit: String?

    public var LocationName: String?
    public var Timezone: String?
    public var Latitude: Float?
    public var Longitude: Float?
    public var Elevation: Int?

    public var ThemeColor: String?

    public var CloudhookURL: URL?
    public var RemoteUIURL: URL?

    public required init?(map: Map) {}

    public func mapping(map: Map) {
        Components <- map["components"]
        Version <- map["version"]

        TemperatureUnit <- map["unit_system.temperature"]
        LengthUnit <- map["unit_system.length"]
        MassUnit <- map["unit_system.mass"]
        PressureUnit <- map["unit_system.pressure"]
        VolumeUnit <- map["unit_system.volume"]

        LocationName <- map["location_name"]
        Timezone <- map["time_zone"]
        Latitude <- map["latitude"]
        Longitude <- map["longitude"]
        Elevation <- map["elevation"]

        ThemeColor <- map["theme_color"]

        CloudhookURL <- (map["cloudhook_url"], URLTransform())
        RemoteUIURL <- (map["remote_ui_url"], URLTransform())
    }
}
