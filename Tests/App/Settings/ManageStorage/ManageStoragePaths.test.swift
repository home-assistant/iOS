import Foundation
@testable import HomeAssistant
import Testing

struct ManageStoragePathsTests {
    @Test func aRootedInventoryGivesEveryRowItsOwnFolder() {
        let root = URL(fileURLWithPath: "/tmp/manage-storage-paths")
        let paths = ManageStoragePaths.rooted(at: root)

        let all = [
            paths.appDatabase, paths.appPreferences, paths.legacyRealmStore, paths.notificationSounds,
            paths.widgetCache, paths.watchItemCache, paths.diskCache, paths.notificationIconCache,
            paths.frontendAssetCache, paths.websiteData,
            paths.clientEventLog, paths.notificationHistory, paths.logFiles, paths.downloads,
            paths.temporaryFiles,
        ].flatMap { $0 }

        #expect(all.count == 15)
        #expect(Set(all).count == 15)
        #expect(all.allSatisfy { $0.deletingLastPathComponent().path == root.path })
        #expect(paths.logFiles.first?.lastPathComponent == ManageStorageItemID.logFiles.rawValue)
    }

    @Test func theLivePathsPointAtSomethingForEveryRow() {
        let paths = ManageStoragePaths.live

        #expect(paths.appDatabase.count == 3, "the database, its write-ahead log and its shared memory file")
        #expect(paths.appDatabase.map(\.lastPathComponent).contains("App.sqlite"))
        #expect(!paths.legacyRealmStore.isEmpty)
        #expect(!paths.widgetCache.isEmpty)
        #expect(!paths.watchItemCache.isEmpty)
        #expect(!paths.clientEventLog.isEmpty)
        #expect(!paths.notificationHistory.isEmpty)
        #expect(!paths.logFiles.isEmpty)
        #expect(!paths.downloads.isEmpty)
        #expect(!paths.temporaryFiles.isEmpty)
        #expect(!paths.appPreferences.isEmpty)
        #expect(!paths.notificationSounds.isEmpty)
        #expect(!paths.diskCache.isEmpty)
        #expect(!paths.notificationIconCache.isEmpty)
        #expect(!paths.frontendAssetCache.isEmpty)
        #expect(!paths.websiteData.isEmpty)
    }

    @Test func theLivePathsAreStable() {
        #expect(ManageStoragePaths.live == ManageStoragePaths.live)
    }
}
