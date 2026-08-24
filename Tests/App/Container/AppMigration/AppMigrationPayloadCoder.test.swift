@testable import HomeAssistant
@testable import Shared
import Foundation
import Testing

struct AppMigrationPayloadCoderTests {
    private func makePayload(serverBytes: Int = 64, configuration: Data? = nil) -> AppMigrationPayload {
        AppMigrationPayload(
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceBundleID: "io.robbie.HomeAssistant",
            sourceAppVersion: "2026.1",
            servers: Self.incompressibleData(count: serverBytes),
            configuration: configuration,
            serverCount: 2,
            configurationEntryCount: 17
        )
    }

    /// Deterministic pseudo-random bytes: real payloads compress well, so a test that needs to
    /// *exceed* a size threshold has to use data zlib cannot shrink.
    private static func incompressibleData(count: Int) -> Data {
        var state: UInt64 = 0x2545_F491_4F6C_DD1D
        var bytes = [UInt8]()
        bytes.reserveCapacity(count)
        for _ in 0 ..< count {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            bytes.append(UInt8(truncatingIfNeeded: state))
        }
        return Data(bytes)
    }

    @Test func roundTripsAPayloadThroughItsChunks() throws {
        let payload = makePayload(configuration: Data("configuration".utf8))

        let chunks = try AppMigrationPayloadCoder.chunks(for: payload, sessionID: "s")
        let assembled = chunks.map(\.data).joined()
        let decoded = try AppMigrationPayloadCoder.payload(fromAssembled: assembled)

        #expect(decoded == payload)
    }

    /// The guarantee that matters for the flow: an ordinary configuration crosses in one link, so the
    /// user never watches the two apps swap.
    @Test func packsAnOrdinaryPayloadIntoASingleChunk() throws {
        let payload = makePayload(serverBytes: 4096, configuration: Data(repeating: 0x7B, count: 32768))

        let chunks = try AppMigrationPayloadCoder.chunks(for: payload, sessionID: "s")

        #expect(chunks.count == 1)
        #expect(chunks[0].isLast)
    }

    @Test func splitsAPayloadTooLargeForOneLink() throws {
        // Incompressible, so the encoded form is guaranteed to exceed one chunk.
        let payload = makePayload(serverBytes: AppMigrationConstants.maximumChunkLength)

        let chunks = try AppMigrationPayloadCoder.chunks(for: payload, sessionID: "session")

        #expect(chunks.count > 1)
        #expect(chunks.allSatisfy { $0.sessionID == "session" })
        #expect(chunks.allSatisfy { $0.total == chunks.count })
        #expect(chunks.map(\.index) == Array(0 ..< chunks.count))
        #expect(chunks.allSatisfy { $0.data.count <= AppMigrationConstants.maximumChunkLength })
        #expect(chunks.dropLast().allSatisfy { !$0.isLast })
        #expect(chunks.last?.isLast == true)
    }

    @Test func rejectsAnAssembledStringThatIsNotAPayload() {
        #expect(throws: AppMigrationCodingError.malformedPayload) {
            try AppMigrationPayloadCoder.payload(fromAssembled: "not-base64url-compressed-anything")
        }
    }

    @Test func rejectsABlobThatIsNotAMigrationPayload() throws {
        let data = try JSONSerialization.data(withJSONObject: ["kind": "something-else"])

        #expect(throws: AppMigrationCodingError.malformedPayload) {
            try AppMigrationPayloadCoder.payload(from: data)
        }
    }

    @Test func rejectsAPayloadFromANewerApp() throws {
        var json = try JSONSerialization.jsonObject(
            with: AppMigrationPayloadCoder.data(for: makePayload())
        ) as! [String: Any]
        json["schemaVersion"] = AppMigrationPayload.currentSchemaVersion + 1
        let data = try JSONSerialization.data(withJSONObject: json)

        #expect(throws: AppMigrationCodingError.unsupportedSchema) {
            try AppMigrationPayloadCoder.payload(from: data)
        }
    }
}
