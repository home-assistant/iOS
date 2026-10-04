import Foundation
import HAKit
@testable import Shared
import Testing

/// Mirrors `Tests/Shared/CoverCapabilities.test.swift`, which isn't a member of any test target.
struct CoverCapabilitiesCoverageTests {
    @Test func positionableCoverSupportsEverything() {
        let capabilities = CoverCapabilities(attributes: [
            "supported_features": 15,
            "current_position": 60,
        ])

        #expect(capabilities.supportsOpen)
        #expect(capabilities.supportsClose)
        #expect(capabilities.supportsStop)
        #expect(capabilities.supportsSetPosition)
        #expect(capabilities.hasAdjustableControls)
        #expect(capabilities.currentPosition == 60)
    }

    @Test func openCloseOnlyCoverHasNoAdjustableControls() {
        let capabilities = CoverCapabilities(attributes: [
            "supported_features": 3,
        ])

        #expect(capabilities.supportsOpen)
        #expect(capabilities.supportsClose)
        #expect(!capabilities.supportsStop)
        #expect(!capabilities.supportsSetPosition)
        #expect(!capabilities.hasAdjustableControls)
        #expect(capabilities.currentPosition == nil)
    }

    @Test func stopWithoutPositionStillGetsControls() {
        let capabilities = CoverCapabilities(attributes: [
            "supported_features": 11,
        ])

        #expect(capabilities.supportsStop)
        #expect(!capabilities.supportsSetPosition)
        #expect(capabilities.hasAdjustableControls)
    }

    @Test func missingFeaturesMeansNoControls() {
        let capabilities = CoverCapabilities(attributes: [:])

        #expect(!capabilities.hasAdjustableControls)
        #expect(!capabilities.supportsOpen)
    }

    @Test func entityInitializerReadsTheAttributes() throws {
        let cover = try entity("cover.garage", attributes: ["supported_features": 4, "current_position": 0])
        let capabilities = CoverCapabilities(entity: cover)
        #expect(capabilities.supportsSetPosition)
        #expect(!capabilities.supportsOpen)
        #expect(capabilities.currentPosition == 0)
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
