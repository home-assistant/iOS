@testable import Shared
import Testing

struct ClimateControlStateTests {
    private var fullAttributes: [String: Any] {
        [
            "hvac_modes": ["off", "heat", "cool", "heat_cool"],
            "hvac_action": "heating",
            "current_temperature": 20.4,
            "temperature": 21.5,
            "target_temp_low": 19.0,
            "target_temp_high": 24.0,
            "min_temp": 10,
            "max_temp": 30,
            "target_temp_step": 1,
            "fan_mode": "auto",
            "fan_modes": ["auto", "low", "high"],
            "swing_mode": "off",
            "swing_modes": ["off", "vertical"],
            "swing_horizontal_mode": "off",
            "swing_horizontal_modes": ["off", "on"],
            "preset_mode": "home",
            "preset_modes": ["home", "away", "eco"],
            "current_humidity": 41.0,
            "humidity": 45.0,
            "min_humidity": 20,
            "max_humidity": 80,
            "supported_features": 0b11_1111_1111,
        ]
    }

    @Test func parsesAllAttributes() {
        let control = ClimateControlState(state: "heat", attributes: fullAttributes)

        #expect(control.hvacMode == "heat")
        #expect(control.hvacModes == ["off", "heat", "cool", "heat_cool"])
        #expect(control.hvacAction == "heating")
        #expect(control.currentTemperature == 20.4)
        #expect(control.targetTemperature == 21.5)
        #expect(control.targetTemperatureLow == 19.0)
        #expect(control.targetTemperatureHigh == 24.0)
        #expect(control.minTemperature == 10)
        #expect(control.maxTemperature == 30)
        #expect(control.temperatureStep == 1)
        #expect(control.fanMode == "auto")
        #expect(control.fanModes == ["auto", "low", "high"])
        #expect(control.swingMode == "off")
        #expect(control.swingModes == ["off", "vertical"])
        #expect(control.swingHorizontalMode == "off")
        #expect(control.swingHorizontalModes == ["off", "on"])
        #expect(control.presetMode == "home")
        #expect(control.presetModes == ["home", "away", "eco"])
        #expect(control.currentHumidity == 41.0)
        #expect(control.targetHumidity == 45.0)
        #expect(control.minHumidity == 20)
        #expect(control.maxHumidity == 80)
    }

    @Test func missingAttributesFallBackToDefaults() {
        let control = ClimateControlState(state: "off", attributes: [:])

        #expect(control.hvacMode == "off")
        #expect(control.hvacModes.isEmpty)
        #expect(control.hvacAction == nil)
        #expect(control.currentTemperature == nil)
        #expect(control.targetTemperature == nil)
        #expect(control.minTemperature == ClimateControlState.defaultMinTemperature)
        #expect(control.maxTemperature == ClimateControlState.defaultMaxTemperature)
        #expect(control.temperatureStep == ClimateControlState.defaultTemperatureStep)
        #expect(control.minHumidity == ClimateControlState.defaultMinHumidity)
        #expect(control.maxHumidity == ClimateControlState.defaultMaxHumidity)
        #expect(control.features.isEmpty)
    }

    @Test func capabilitiesRequireFeatureBitAndOptions() {
        let control = ClimateControlState(state: "heat", attributes: fullAttributes)
        #expect(control.supportsTargetTemperature)
        #expect(control.supportsTargetTemperatureRange)
        #expect(control.supportsTargetHumidity)
        #expect(control.supportsFanMode)
        #expect(control.supportsSwingMode)
        #expect(control.supportsSwingHorizontalMode)
        #expect(control.supportsPresetMode)
        #expect(control.supportsHvacModes)

        // Feature bit set but no options → the mode pickers have nothing to offer.
        var attributes = fullAttributes
        attributes["fan_modes"] = []
        attributes["swing_modes"] = []
        attributes["preset_modes"] = []
        attributes["swing_horizontal_modes"] = []
        let withoutOptions = ClimateControlState(state: "heat", attributes: attributes)
        #expect(!withoutOptions.supportsFanMode)
        #expect(!withoutOptions.supportsSwingMode)
        #expect(!withoutOptions.supportsSwingHorizontalMode)
        #expect(!withoutOptions.supportsPresetMode)

        // Options present but feature bit unset → the entity doesn't support the service.
        attributes = fullAttributes
        attributes["supported_features"] = 0
        let withoutFeatures = ClimateControlState(state: "heat", attributes: attributes)
        #expect(!withoutFeatures.supportsTargetTemperature)
        #expect(!withoutFeatures.supportsTargetTemperatureRange)
        #expect(!withoutFeatures.supportsTargetHumidity)
        #expect(!withoutFeatures.supportsFanMode)
        #expect(!withoutFeatures.supportsSwingMode)
        #expect(!withoutFeatures.supportsSwingHorizontalMode)
        #expect(!withoutFeatures.supportsPresetMode)
    }

    @Test func clampingRespectsBounds() {
        let control = ClimateControlState(state: "heat", attributes: fullAttributes)
        #expect(control.clampTemperature(5) == 10)
        #expect(control.clampTemperature(35) == 30)
        #expect(control.clampTemperature(22) == 22)
        #expect(control.clampHumidity(10) == 20)
        #expect(control.clampHumidity(90) == 80)
        #expect(control.clampHumidity(50) == 50)
    }

    @Test func featureBitmaskMatchesCore() {
        #expect(ClimateEntityFeature.targetTemperature.rawValue == 1)
        #expect(ClimateEntityFeature.targetTemperatureRange.rawValue == 2)
        #expect(ClimateEntityFeature.targetHumidity.rawValue == 4)
        #expect(ClimateEntityFeature.fanMode.rawValue == 8)
        #expect(ClimateEntityFeature.presetMode.rawValue == 16)
        #expect(ClimateEntityFeature.swingMode.rawValue == 32)
        #expect(ClimateEntityFeature.auxHeat.rawValue == 64)
        #expect(ClimateEntityFeature.turnOff.rawValue == 128)
        #expect(ClimateEntityFeature.turnOn.rawValue == 256)
        #expect(ClimateEntityFeature.swingHorizontalMode.rawValue == 512)

        let features = ClimateEntityFeature(attributes: ["supported_features": 9])
        #expect(features.contains(.targetTemperature))
        #expect(features.contains(.fanMode))
        #expect(!features.contains(.presetMode))
    }

    @Test func hvacModeRawValuesMatchCore() {
        let expected: [ClimateHvacMode: String] = [
            .off: "off",
            .heat: "heat",
            .cool: "cool",
            .heatCool: "heat_cool",
            .auto: "auto",
            .dry: "dry",
            .fanOnly: "fan_only",
        ]
        #expect(Set(ClimateHvacMode.allCases) == Set(expected.keys))
        for (mode, rawValue) in expected {
            #expect(mode.rawValue == rawValue)
        }
    }

    @Test func unknownModesAreHumanized() {
        // Unknown HVAC modes and free-form fan/swing/preset values fall back to a humanized string.
        #expect(ClimateHvacMode.localizedTitle(forMode: "super_boost") == "Super boost")
        #expect(ClimateControlState.displayName(forMode: "middle_low") == "Middle low")
    }
}
