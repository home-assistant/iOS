import Foundation
import HAKit
@testable import Shared
import Testing

/// Mirrors `Tests/Shared/LightCapabilities.test.swift`, which isn't a member of any test target.
struct LightCapabilitiesCoverageTests {
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
        #expect(capabilities.supportsColor)
        #expect(capabilities.hasAdjustableControls)
        #expect(capabilities.brightnessPercentage == 50)
        #expect(capabilities.colorTempKelvin == 3200)
        #expect(capabilities.minColorTempKelvin == 2202)
        #expect(capabilities.maxColorTempKelvin == 6535)
    }

    @Test func colorOnlyLightHasAdjustableControls() {
        let capabilities = LightCapabilities(attributes: [
            "supported_color_modes": ["hs"],
        ])

        #expect(capabilities.supportsColor)
        #expect(capabilities.supportsBrightness)
        #expect(!capabilities.supportsColorTemp)
        #expect(capabilities.hasAdjustableControls)
    }

    @Test func brightnessOnlyLightHasNoTemperature() {
        let capabilities = LightCapabilities(attributes: [
            "supported_color_modes": ["brightness"],
            "brightness": 255,
        ])

        #expect(capabilities.supportsBrightness)
        #expect(!capabilities.supportsColorTemp)
        #expect(!capabilities.supportsColor)
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

    @Test func entityInitializerReadsTheAttributes() throws {
        let light = try entity("light.kitchen", attributes: [
            "supported_color_modes": ["rgb"],
            "brightness": 255,
        ])
        let capabilities = LightCapabilities(entity: light)
        #expect(capabilities == LightCapabilities(attributes: light.attributes.dictionary))
        #expect(capabilities.supportsColor)
        #expect(capabilities.brightnessPercentage == 100)
    }

    @Test func legacyLightsAreReadFromTheirValueAttributes() {
        let capabilities = LightCapabilities(attributes: [
            "color_temp_kelvin": 3000.0,
            "hs_color": [30.0, 50.0],
        ])
        #expect(!capabilities.supportsBrightness)
        #expect(capabilities.supportsColorTemp)
        #expect(capabilities.supportsColor)
        #expect(capabilities.colorTempKelvin == 3000)
        #expect(capabilities.brightnessPercentage == nil)
    }

    @Test func colorModesReportWhatTheyCanDo() {
        #expect(!LightCapabilities.ColorMode.onoff.supportsBrightness)
        #expect(LightCapabilities.ColorMode.white.supportsBrightness)
        #expect(!LightCapabilities.ColorMode.white.supportsColor)
        #expect(!LightCapabilities.ColorMode.colorTemp.supportsColor)
        for mode in [LightCapabilities.ColorMode.hs, .xy, .rgb, .rgbw, .rgbww] {
            #expect(mode.supportsColor)
        }
    }

    private func entity(_ entityId: String, attributes: [String: Any]) throws -> HAEntity {
        try HAEntity(
            entityId: entityId,
            state: "on",
            lastChanged: Date(timeIntervalSince1970: 0),
            lastUpdated: Date(timeIntervalSince1970: 0),
            attributes: attributes,
            context: .init(id: "context", userId: nil, parentId: nil)
        )
    }
}
