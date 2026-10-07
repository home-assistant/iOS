import Foundation
@testable import Shared
import Testing

struct LockCapabilitiesTests {
    @Test func openFeatureBitEnablesOpen() {
        let capabilities = LockCapabilities(attributes: [
            "supported_features": 1,
        ])

        #expect(capabilities.supportsOpen)
    }

    @Test func missingFeaturesMeansNoOpen() {
        #expect(!LockCapabilities(attributes: [:]).supportsOpen)
        #expect(!LockCapabilities(attributes: ["supported_features": 0]).supportsOpen)
    }
}
