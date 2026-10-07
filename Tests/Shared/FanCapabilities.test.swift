import Foundation
@testable import Shared
import Testing

struct FanCapabilitiesTests {
    @Test func speedFanSupportsPercentage() {
        let capabilities = FanCapabilities(attributes: [
            "supported_features": 1,
            "percentage": 50,
            "percentage_step": 25,
        ])

        #expect(capabilities.supportsSpeedPercentage)
        #expect(capabilities.hasAdjustableControls)
        #expect(capabilities.speedPercentage == 50)
        #expect(capabilities.percentageStep == 25)
    }

    @Test func onOffFanHasNoAdjustableControls() {
        let capabilities = FanCapabilities(attributes: [
            "supported_features": 0,
        ])

        #expect(!capabilities.supportsSpeedPercentage)
        #expect(!capabilities.hasAdjustableControls)
        #expect(capabilities.speedPercentage == nil)
    }

    @Test func missingStepDefaultsToOne() {
        let capabilities = FanCapabilities(attributes: [
            "supported_features": 1,
        ])

        #expect(capabilities.percentageStep == 1)
    }

    @Test func zeroStepFallsBackToOne() {
        let capabilities = FanCapabilities(attributes: [
            "supported_features": 1,
            "percentage_step": 0,
        ])

        #expect(capabilities.percentageStep == 1)
    }
}
