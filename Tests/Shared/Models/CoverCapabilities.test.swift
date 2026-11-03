import Foundation
@testable import Shared
import Testing

struct CoverCapabilitiesTests {
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
}
