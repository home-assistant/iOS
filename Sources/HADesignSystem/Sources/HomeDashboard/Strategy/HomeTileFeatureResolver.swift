import Foundation

/// Which control a tile gets, if any. The port of the frontend's `computeAreaTileCardConfig`, which
/// walks its `supports…CardFeature` checks in order and takes the first that fits.
public enum HomeTileFeatureResolver {
    /// The bits Home Assistant uses in `supported_features`, for the domains that matter here.
    private enum Feature {
        static let coverOpen = 1
        static let coverClose = 2
        static let fanSetSpeed = 1
        static let climateTargetTemperature = 1
        static let climateTargetTemperatureRange = 2
        static let waterHeaterTargetTemperature = 1
    }

    /// The colour modes a light has to have one of before it can be dimmed.
    private static let brightnessColorModes: Set<String> = [
        "hs", "xy", "rgb", "rgbw", "rgbww", "color_temp", "brightness", "white",
    ]

    public static func feature(for state: HomeEntityState) -> HomeTileFeature? {
        let domain = state.domain
        let supported = state.attributes.supportedFeatures ?? 0

        if domain == "light", supportsBrightness(state) {
            return .lightBrightness
        }
        if domain == "cover", supported & (Feature.coverOpen | Feature.coverClose) != 0 {
            return .coverOpenClose
        }
        if domain == "climate",
           supported & (Feature.climateTargetTemperature | Feature.climateTargetTemperatureRange) != 0 {
            return .targetTemperature
        }
        if domain == "water_heater", supported & Feature.waterHeaterTargetTemperature != 0 {
            return .targetTemperature
        }
        if domain == "fan", supported & Feature.fanSetSpeed != 0 {
            return .fanSpeed
        }
        if domain == "alarm_control_panel" {
            return .alarmModes
        }
        if domain == "lock" {
            return .lockCommands
        }
        return nil
    }

    private static func supportsBrightness(_ state: HomeEntityState) -> Bool {
        guard let modes = state.attributes.supportedColorModes else {
            return false
        }
        return modes.contains { brightnessColorModes.contains($0) }
    }
}
