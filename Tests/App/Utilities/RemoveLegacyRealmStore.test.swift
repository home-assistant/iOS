import Foundation
@testable import HomeAssistant
import Testing

struct RemoveLegacyRealmStoreTests {
    @Test func removesTheLegacyStoreAndNothingElse() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("remove-legacy-realm-store-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = ManageStoragePaths.rooted(at: root)
        let store = try #require(paths.legacyRealmStore.first)
        let database = try #require(paths.appDatabase.first)
        try FileManager.default.createDirectory(at: store, withIntermediateDirectories: true)
        try Data("realm".utf8).write(to: store.appendingPathComponent("store.realm"))
        try FileManager.default.createDirectory(at: database, withIntermediateDirectories: true)

        removeLegacyRealmStore(paths: paths)

        #expect(!FileManager.default.fileExists(atPath: store.path))
        #expect(FileManager.default.fileExists(atPath: database.path))
    }

    @Test func doesNothingWhenThereIsNoLegacyStore() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("remove-legacy-realm-store-\(UUID().uuidString)", isDirectory: true)

        removeLegacyRealmStore(paths: .rooted(at: root))

        #expect(!FileManager.default.fileExists(atPath: root.path))
    }
}
