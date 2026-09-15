#if !os(watchOS)
import HAIconic

/// The icon an entity gets when neither it nor its registry entry names one: its device class, then
/// its domain. A short table covering what the home dashboard shows, which the app replaces with its
/// own `EntityIconResolver` through ``HomeEntityPresenter``.
public enum HomeDomainIcon {
    public static func icon(for state: HomeEntityState) -> MaterialDesignIcons {
        if let deviceClass = state.attributes.deviceClass, let icon = deviceClassIcon(deviceClass) {
            return icon
        }
        return domainIcon(state.domain, state: state.state)
    }

    private static func deviceClassIcon(_ deviceClass: String) -> MaterialDesignIcons? {
        switch deviceClass {
        case "temperature": .thermometerIcon
        case "humidity": .waterPercentIcon
        case "battery": .batteryIcon
        case "door": .doorClosedIcon
        case "garage": .garageIcon
        case "window": .windowClosedVariantIcon
        case "motion": .motionSensorIcon
        case "power", "energy": .flashIcon
        case "pm25", "pm10": .moleculeIcon
        default: nil
        }
    }

    private static func domainIcon(_ domain: String, state: String) -> MaterialDesignIcons {
        switch domain {
        case "light": .lightbulbIcon
        case "switch": .toggleSwitchVariantIcon
        case "climate": .thermostatIcon
        case "fan": .fanIcon
        case "media_player": .speakerIcon
        case "lock": state == "locked" ? .lockIcon : .lockOpenIcon
        case "cover": .windowShutterIcon
        case "camera": .videoIcon
        case "scene": .paletteIcon
        case "script": .scriptTextIcon
        case "automation": .robotIcon
        case "person", "device_tracker": .accountIcon
        case "weather": .weatherPartlyCloudyIcon
        case "vacuum": .robotVacuumIcon
        case "binary_sensor": .checkboxMarkedCircleIcon
        case "sensor": .eyeIcon
        case "zone": .mapMarkerRadiusIcon
        default: .dotsGridIcon
        }
    }
}
#endif
