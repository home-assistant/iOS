import Foundation

/// The climate domain's well-known `hvac_modes` values, mirroring Home Assistant core's `HVACMode`.
///
/// Integrations can only report these modes, but parse defensively: unknown raw values fall back to
/// a humanized version of the raw string (see `localizedTitle(forMode:)`).
public enum ClimateHvacMode: String, CaseIterable {
    case off
    case heat
    case cool
    case heatCool = "heat_cool"
    case auto
    case dry
    case fanOnly = "fan_only"

    public var title: String {
        switch self {
        case .off:
            return L10n.Climate.HvacMode.off
        case .heat:
            return L10n.Climate.HvacMode.heat
        case .cool:
            return L10n.Climate.HvacMode.cool
        case .heatCool:
            return L10n.Climate.HvacMode.heatCool
        case .auto:
            return L10n.Climate.HvacMode.auto
        case .dry:
            return L10n.Climate.HvacMode.dry
        case .fanOnly:
            return L10n.Climate.HvacMode.fanOnly
        }
    }

    /// Icon matching the frontend's HVAC mode iconography.
    public var icon: MaterialDesignIcons {
        switch self {
        case .off:
            return .powerIcon
        case .heat:
            return .fireIcon
        case .cool:
            return .snowflakeIcon
        case .heatCool:
            return .sunSnowflakeVariantIcon
        case .auto:
            return .thermostatAutoIcon
        case .dry:
            return .waterPercentIcon
        case .fanOnly:
            return .fanIcon
        }
    }

    /// Localized display name for a raw `hvac_modes` value, falling back to the humanized raw value
    /// for modes this app doesn't know about.
    public static func localizedTitle(forMode mode: String) -> String {
        if let known = ClimateHvacMode(rawValue: mode) {
            return known.title
        }
        return ClimateControlState.displayName(forMode: mode)
    }
}
