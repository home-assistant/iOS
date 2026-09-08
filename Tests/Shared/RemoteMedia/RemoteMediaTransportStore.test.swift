import Foundation
@testable import Shared
import Testing

/// Serialized: these swap the store's shared storage.
@Suite(.serialized)
struct RemoteMediaTransportStoreTests {
    /// Stands in for the Keychain. The unit test bundle has no `keychain-access-groups` entitlement,
    /// so every real `SecItem` call there fails with `errSecMissingEntitlement`.
    private final class MemoryStorage: RemoteMediaSecureStorage, @unchecked Sendable {
        var stored: Data?
        var saveCount = 0
        func data() -> Data? { stored }
        func save(_ data: Data) throws {
            saveCount += 1
            stored = data
        }

        func clear() { stored = nil }
    }

    private let selection = RemoteMediaSelection(serverId: "home", entityId: "media_player.speaker")

    private func context(
        _ selection: RemoteMediaSelection,
        secret: [UInt8]? = [1, 2, 3]
    ) -> RemoteMediaTransportContext {
        .init(
            selection: selection,
            webhookURLs: [URL(string: "https://ha.example.com/api/webhook/abc")!],
            secret: secret
        )
    }

    private func withMemoryStorage(_ body: (MemoryStorage) throws -> Void) rethrows {
        let previous = RemoteMediaTransportStore.storage
        let storage = MemoryStorage()
        RemoteMediaTransportStore.storage = storage
        defer { RemoteMediaTransportStore.storage = previous }
        try body(storage)
    }

    @Test func contextRoundTrips() throws {
        try withMemoryStorage { _ in
            let stored = context(selection)
            try RemoteMediaTransportStore.save(stored)
            #expect(RemoteMediaTransportStore.load() == stored)
        }
    }

    @Test func savingAgainReplacesRatherThanDuplicating() throws {
        try withMemoryStorage { storage in
            try RemoteMediaTransportStore.save(context(selection))
            let other = RemoteMediaSelection(serverId: "home", entityId: "media_player.other")
            try RemoteMediaTransportStore.save(context(other))
            #expect(RemoteMediaTransportStore.load()?.selection == other)
            #expect(storage.saveCount == 2)
        }
    }

    @Test func clearingRemovesTheSecret() throws {
        try withMemoryStorage { storage in
            try RemoteMediaTransportStore.save(context(selection))
            RemoteMediaTransportStore.clear()
            #expect(storage.stored == nil)
            #expect(RemoteMediaTransportStore.load() == nil)
            // Clearing twice is not an error.
            RemoteMediaTransportStore.clear()
        }
    }

    @Test func aRegistrationWithoutASecretIsStoredAsPlaintextCapable() throws {
        try withMemoryStorage { _ in
            try RemoteMediaTransportStore.save(context(selection, secret: nil))
            #expect(RemoteMediaTransportStore.load()?.secret == nil)
        }
    }

    @Test func corruptStoredBytesReadAsAbsent() {
        withMemoryStorage { storage in
            storage.stored = Data("not json".utf8)
            #expect(RemoteMediaTransportStore.load() == nil)
        }
    }

    /// The secret is what the whole separation exists to protect: it must survive the round trip
    /// intact, and it must be the only place it lives.
    @Test func secretSurvivesTheRoundTripByteForByte() throws {
        try withMemoryStorage { storage in
            let secret: [UInt8] = (0 ..< 32).map { UInt8($0) }
            try RemoteMediaTransportStore.save(context(selection, secret: secret))
            #expect(RemoteMediaTransportStore.load()?.secret == secret)
            // And what is written is the encoded context, not something lossy.
            let raw = try #require(storage.stored)
            let decoded = try JSONDecoder().decode(RemoteMediaTransportContext.self, from: raw)
            #expect(decoded.secret == secret)
        }
    }
}
