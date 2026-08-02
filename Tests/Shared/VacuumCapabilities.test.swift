import Foundation
@testable import Shared
import Testing

struct VacuumCapabilitiesTests {
    @Test func fullFeaturedVacuumSupportsEverything() {
        let capabilities = VacuumCapabilities(attributes: [
            "supported_features": 25212,
            "battery_level": 80,
            "fan_speed": "medium",
            "fan_speed_list": ["quiet", "medium", "high", "max"],
        ])

        #expect(capabilities.supportsStart)
        #expect(capabilities.supportsPause)
        #expect(capabilities.supportsStop)
        #expect(capabilities.supportsReturnHome)
        #expect(capabilities.supportsLocate)
        #expect(capabilities.supportsCleanArea)
        #expect(capabilities.supportsFanSpeed)
        #expect(capabilities.fanSpeed == "medium")
        #expect(capabilities.fanSpeedList == ["quiet", "medium", "high", "max"])
        #expect(capabilities.batteryLevel == 80)
    }

    @Test func featureBitsMatchCore() {
        #expect(VacuumCapabilities.Feature.pause.rawValue == 4)
        #expect(VacuumCapabilities.Feature.stop.rawValue == 8)
        #expect(VacuumCapabilities.Feature.returnHome.rawValue == 16)
        #expect(VacuumCapabilities.Feature.fanSpeed.rawValue == 32)
        #expect(VacuumCapabilities.Feature.battery.rawValue == 64)
        #expect(VacuumCapabilities.Feature.locate.rawValue == 512)
        #expect(VacuumCapabilities.Feature.start.rawValue == 8192)
        #expect(VacuumCapabilities.Feature.cleanArea.rawValue == 16384)
    }

    @Test func bareVacuumSupportsNothing() {
        let capabilities = VacuumCapabilities(attributes: [:])

        #expect(!capabilities.supportsStart)
        #expect(!capabilities.supportsPause)
        #expect(!capabilities.supportsStop)
        #expect(!capabilities.supportsReturnHome)
        #expect(!capabilities.supportsLocate)
        #expect(!capabilities.supportsCleanArea)
        #expect(!capabilities.supportsFanSpeed)
        #expect(capabilities.fanSpeed == nil)
        #expect(capabilities.fanSpeedList.isEmpty)
        #expect(capabilities.batteryLevel == nil)
    }

    @Test func fanSpeedRequiresBitAndOptions() {
        // Feature bit set but no speed list → the picker has nothing to offer.
        let withoutOptions = VacuumCapabilities(attributes: [
            "supported_features": 32,
        ])
        #expect(!withoutOptions.supportsFanSpeed)

        // Speed list present but feature bit unset → the entity doesn't support the service.
        let withoutBit = VacuumCapabilities(attributes: [
            "supported_features": 0,
            "fan_speed_list": ["low", "high"],
        ])
        #expect(!withoutBit.supportsFanSpeed)
    }

    @Test func batteryRequiresFeatureBit() {
        // A reported battery_level without the feature bit isn't advertised as supported.
        let capabilities = VacuumCapabilities(attributes: [
            "supported_features": 0,
            "battery_level": 55,
        ])
        #expect(capabilities.batteryLevel == nil)
    }
}
