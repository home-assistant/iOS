import Foundation
import HAKit
@testable import Shared
import Testing

/// Mirrors `Tests/Shared/FanCapabilities.test.swift`, which isn't a member of any test target.
struct FanCapabilitiesCoverageTests {
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

    @Test func entityInitializerReadsTheAttributes() throws {
        let fan = try entity("fan.bedroom", attributes: ["supported_features": 1, "percentage": 75])
        let capabilities = FanCapabilities(entity: fan)
        #expect(capabilities.supportsSpeedPercentage)
        #expect(capabilities.speedPercentage == 75)
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
