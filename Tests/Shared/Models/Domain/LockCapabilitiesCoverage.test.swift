import Foundation
import HAKit
@testable import Shared
import Testing

/// Mirrors `Tests/Shared/LockCapabilities.test.swift`, which isn't a member of any test target.
struct LockCapabilitiesCoverageTests {
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

    @Test func entityInitializerReadsTheAttributes() throws {
        let lock = try entity("lock.front", attributes: ["supported_features": 1])
        #expect(LockCapabilities(entity: lock).supportsOpen)
        let plainLock = try entity("lock.back", attributes: [:])
        #expect(!LockCapabilities(entity: plainLock).supportsOpen)
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
