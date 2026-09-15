import Foundation

/// The attributes the home dashboard's cards and filters read. Deliberately a fixed set rather than
/// a dictionary of `Any`: everything here is either filtered on or drawn, and a typed value is what
/// makes the strategies testable without a server.
public struct HomeEntityAttributes: Equatable, Hashable, Sendable {
    /// `friendly_name`, the name the state carries.
    public let friendlyName: String?
    /// `device_class` — what a sensor or a cover actually is. Filters lean on it heavily.
    public let deviceClass: String?
    /// An icon set on the state, which beats the domain's default.
    public let icon: String?
    /// `unit_of_measurement`, appended to a numeric state.
    public let unitOfMeasurement: String?
    /// `supported_features`, the bitmask that says which controls an entity accepts.
    public let supportedFeatures: Int?
    /// `brightness`, 0–255, for lights that dim.
    public let brightness: Int?
    /// `current_temperature`, what a thermostat reads right now.
    public let currentTemperature: Double?
    /// `temperature`, what a thermostat is set to.
    public let targetTemperature: Double?
    /// `hvac_action`, what a thermostat is doing about it.
    public let hvacAction: String?
    /// `media_title`, what a player is playing.
    public let mediaTitle: String?
    /// `supported_color_modes`, which says whether a light dims at all.
    public let supportedColorModes: [String]?

    public init(
        friendlyName: String? = nil,
        deviceClass: String? = nil,
        icon: String? = nil,
        unitOfMeasurement: String? = nil,
        supportedFeatures: Int? = nil,
        brightness: Int? = nil,
        currentTemperature: Double? = nil,
        targetTemperature: Double? = nil,
        hvacAction: String? = nil,
        mediaTitle: String? = nil,
        supportedColorModes: [String]? = nil
    ) {
        self.friendlyName = friendlyName
        self.deviceClass = deviceClass
        self.icon = icon
        self.unitOfMeasurement = unitOfMeasurement
        self.supportedFeatures = supportedFeatures
        self.brightness = brightness
        self.currentTemperature = currentTemperature
        self.targetTemperature = targetTemperature
        self.hvacAction = hvacAction
        self.mediaTitle = mediaTitle
        self.supportedColorModes = supportedColorModes
    }
}
