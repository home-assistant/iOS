import Foundation
@testable import HomeAssistant
import Shared
import Testing

struct ManageStorageInventoryTests {
    private let paths = ManageStoragePaths.rooted(at: URL(fileURLWithPath: "/tmp/manage-storage-inventory"))

    private func items(
        isCatalyst: Bool = false,
        hasCompletedLegacyStoreMigration: Bool = true
    ) -> [ManageStorageItem] {
        ManageStorageInventory.items(
            paths: paths,
            isCatalyst: isCatalyst,
            hasCompletedLegacyStoreMigration: hasCompletedLegacyStoreMigration
        )
    }

    @Test func everyKnownStorageItemIsListedExactlyOnce() {
        let ids = items().map(\.id)

        #expect(Set(ids) == Set(ManageStorageItemID.allCases))
        #expect(ids.count == ManageStorageItemID.allCases.count)
    }

    @Test func theAppDatabaseAndTheThingsTheUserOwnsAreNeverDeletable() {
        let protectedIDs = Set(items().filter { !$0.isDeletable }.map(\.id))

        #expect(protectedIDs == [.appDatabase, .appPreferences, .notificationSounds])
    }

    @Test func theDatabaseAndPreferencesAreProtectedAsEssentialData() {
        let byID = Dictionary(uniqueKeysWithValues: items().map { ($0.id, $0) })

        #expect(byID[.appDatabase]?.protection == .protected(.essentialAppData))
        #expect(byID[.appPreferences]?.protection == .protected(.essentialAppData))
        #expect(byID[.notificationSounds]?.protection == .protected(.userProvidedContent))
    }

    @Test func theLegacyStoreIsOnlyDeletableOnceItHasBeenImported() {
        let pending = items(hasCompletedLegacyStoreMigration: false)
            .first { $0.id == .legacyRealmStore }
        let imported = items(hasCompletedLegacyStoreMigration: true)
            .first { $0.id == .legacyRealmStore }

        #expect(pending?.protection == .protected(.pendingMigration))
        #expect(imported?.protection == .deletable)
    }

    @Test func theUsersOwnDownloadsFolderIsProtectedOnMac() {
        let onMac = items(isCatalyst: true).first { $0.id == .downloads }
        let onPhone = items(isCatalyst: false).first { $0.id == .downloads }

        #expect(onMac?.protection == .protected(.outsideAppControl))
        #expect(onPhone?.protection == .deletable)
    }

    @Test func onlyRowsStoredInsideTheDatabaseAreLeftOutOfTheTotal() {
        let notCounted = Set(items().filter { !$0.countsTowardTotal }.map(\.id))

        #expect(notCounted == [.cachedEntities, .cachedCalendarEvents, .locationHistory])
        for item in items() where !item.countsTowardTotal {
            if case .databaseTables = item.source { continue }
            Issue.record("\(item.id.rawValue) is not backed by database tables")
        }
    }

    @Test func databaseBackedRowsNameRealTables() {
        let byID = Dictionary(uniqueKeysWithValues: items().map { ($0.id, $0) })

        #expect(byID[.cachedEntities]?.source == .databaseTables([
            GRDBDatabaseTable.HAAppEntity.rawValue,
            GRDBDatabaseTable.displayEntityRegistry.rawValue,
            GRDBDatabaseTable.deviceRegistry.rawValue,
        ]))
        #expect(byID[.cachedCalendarEvents]?.source == .databaseTables([
            GRDBDatabaseTable.HACalendarEvent.rawValue,
        ]))
        #expect(byID[.locationHistory]?.source == .databaseTables([
            GRDBDatabaseTable.locationHistory.rawValue,
            GRDBDatabaseTable.locationError.rawValue,
        ]))
    }

    @Test func webContentRowsClearDistinctWebKitDataTypes() {
        let byID = Dictionary(uniqueKeysWithValues: items().map { ($0.id, $0) })

        guard let frontend = byID[.frontendAssetCache], let website = byID[.websiteData],
              case let .webKit(_, assetTypes) = frontend.source,
              case let .webKit(_, dataTypes) = website.source else {
            Issue.record("web content rows are not backed by WebKit")
            return
        }

        #expect(assetTypes == WebsiteDataStoreHandlerImpl.frontendAssetDataTypes)
        #expect(dataTypes == ManageStorageInventory.websiteDataTypes)
        #expect(assetTypes.isDisjoint(with: dataTypes))
    }

    @Test func fileBackedRowsUseTheSuppliedPaths() {
        let byID = Dictionary(uniqueKeysWithValues: items().map { ($0.id, $0) })

        #expect(byID[.appDatabase]?.source == .files(paths.appDatabase))
        #expect(byID[.logFiles]?.source == .files(paths.logFiles))
        #expect(byID[.temporaryFiles]?.source == .files(paths.temporaryFiles))
        #expect(byID[.networkResponseCache]?.source == .networkResponseCache)
    }

    @Test func everyRowLandsInACategoryThatDescribesIt() {
        let byID = Dictionary(uniqueKeysWithValues: items().map { ($0.id, $0.category) })

        #expect(byID[.appDatabase] == .appData)
        #expect(byID[.cachedEntities] == .caches)
        #expect(byID[.frontendAssetCache] == .webContent)
        #expect(byID[.logFiles] == .logs)
        #expect(byID[.downloads] == .downloads)
        #expect(byID[.temporaryFiles] == .temporary)
        #expect(Set(byID.values) == Set(ManageStorageCategory.allCases))
    }
}
