import Foundation
@testable import HomeAssistant
import Testing

struct RemoveResetCachesTests {
    @Test func removesTheResetCachesAndNothingElse() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("remove-reset-caches-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = ManageStoragePaths.rooted(at: root)
        let store = try #require(paths.legacyRealmStore.first)
        let widgetCache = try #require(paths.widgetCache.first)
        let watchItemCache = try #require(paths.watchItemCache.first)
        let database = try #require(paths.appDatabase.first)
        try FileManager.default.createDirectory(at: store, withIntermediateDirectories: true)
        try Data("realm".utf8).write(to: store.appendingPathComponent("store.realm"))
        try FileManager.default.createDirectory(at: widgetCache, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: watchItemCache, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: database, withIntermediateDirectories: true)

        removeResetCaches(paths: paths)

        #expect(!FileManager.default.fileExists(atPath: store.path))
        #expect(!FileManager.default.fileExists(atPath: widgetCache.path))
        #expect(!FileManager.default.fileExists(atPath: watchItemCache.path))
        #expect(FileManager.default.fileExists(atPath: database.path))
    }

    @Test func doesNothingWhenThereAreNoCaches() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("remove-reset-caches-\(UUID().uuidString)", isDirectory: true)

        removeResetCaches(paths: .rooted(at: root))

        #expect(!FileManager.default.fileExists(atPath: root.path))
    }
}
