import Foundation
@testable import Shared
import Testing

struct LightCapabilitiesTests {
    @Test func colorTempLightSupportsBrightnessAndTemperature() {
        let capabilities = LightCapabilities(attributes: [
            "supported_color_modes": ["color_temp", "xy"],
            "brightness": 128,
            "color_temp_kelvin": 3200,
            "min_color_temp_kelvin": 2202,
            "max_color_temp_kelvin": 6535,
        ])

        #expect(capabilities.supportsBrightness)
        #expect(capabilities.supportsColorTemp)
        #expect(capabilities.hasAdjustableControls)
        #expect(capabilities.brightnessPercentage == 50)
        #expect(capabilities.colorTempKelvin == 3200)
        #expect(capabilities.minColorTempKelvin == 2202)
        #expect(capabilities.maxColorTempKelvin == 6535)
    }

    @Test func brightnessOnlyLightHasNoTemperature() {
        let capabilities = LightCapabilities(attributes: [
            "supported_color_modes": ["brightness"],
            "brightness": 255,
        ])

        #expect(capabilities.supportsBrightness)
        #expect(!capabilities.supportsColorTemp)
        #expect(capabilities.hasAdjustableControls)
        #expect(capabilities.brightnessPercentage == 100)
    }

    @Test func onOffLightHasNoAdjustableControls() {
        let capabilities = LightCapabilities(attributes: [
            "supported_color_modes": ["onoff"],
        ])

        #expect(!capabilities.supportsBrightness)
        #expect(!capabilities.supportsColorTemp)
        #expect(!capabilities.hasAdjustableControls)
        #expect(capabilities.brightnessPercentage == nil)
    }

    @Test func offLightKeepsCapabilitiesWithoutCurrentValues() {
        let capabilities = LightCapabilities(attributes: [
            "supported_color_modes": ["color_temp"],
        ])

        #expect(capabilities.supportsBrightness)
        #expect(capabilities.supportsColorTemp)
        #expect(capabilities.brightnessPercentage == nil)
        #expect(capabilities.colorTempKelvin == nil)
    }

    @Test func missingColorModesFallsBackToBrightnessAttribute() {
        let capabilities = LightCapabilities(attributes: [
            "brightness": 64,
        ])

        #expect(capabilities.supportsBrightness)
        #expect(!capabilities.supportsColorTemp)
        #expect(capabilities.brightnessPercentage == 25)
    }

    @Test func missingKelvinRangeUsesDefaults() {
        let capabilities = LightCapabilities(attributes: [
            "supported_color_modes": ["color_temp"],
        ])

        #expect(capabilities.minColorTempKelvin == LightCapabilities.defaultMinColorTempKelvin)
        #expect(capabilities.maxColorTempKelvin == LightCapabilities.defaultMaxColorTempKelvin)
    }

    @Test func unknownModesAreIgnored() {
        let capabilities = LightCapabilities(attributes: [
            "supported_color_modes": ["something_new", "onoff"],
        ])

        #expect(!capabilities.supportsBrightness)
        #expect(!capabilities.hasAdjustableControls)
    }
}
