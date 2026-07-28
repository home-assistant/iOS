import GRDB
@testable import Shared
import Testing

struct CarPlayConfigTests {
    @Test func validateCarPlayConfigScheme() async throws {
        let currentFileURL = URL(fileURLWithPath: #file)
        let directoryURL = currentFileURL.deletingLastPathComponent()
        let sqliteFileURL = directoryURL.appendingPathComponent("CarPlayConfigV1.sqlite")
        let database = try DatabaseQueue(path: sqliteFileURL.path)
        let carPlayConfig = try await database.read { db in
            try CarPlayConfig.fetchOne(db)
        }

        #expect(carPlayConfig?.id == "carplay-config", "CarPlay config id is wrong")
        #expect(carPlayConfig?.tabs == [
            .quickAccess,
            .areas,
            .domains,
        ], "CarPlay config tabs is wrong")
        #expect(carPlayConfig?.quickAccessItems == [
            .init(
                id: "script.new_script_2",
                serverId: "c4f59c50552e4aebbbaffd5754aa2e9f",
                type: .script,
                customization: .init(
                    iconColor: "00AEF8",
                    requiresConfirmation: true
                )
            ),
            .init(
                id: "script.new_script_5",
                serverId: "c4f59c50552e4aebbbaffd5754aa2e9f",
                type: .script,
                customization: .init(
                    iconColor: "00AEF8",
                    textColor: "#FFFFFFFF",
                    backgroundColor: "#000000FF",
                    requiresConfirmation: false
                )
            ),
        ], "CarPlay config has wrong items config")
        #expect(carPlayConfig?.quickAccessLayout == nil, "CarPlay config quick access layout should default to nil")
        #expect(
            carPlayConfig?.showAddEditButtons == nil,
            "CarPlay config showAddEditButtons should be nil when column is absent"
        )
        #expect(
            carPlayConfig?.tabFolders == nil,
            "CarPlay config tabFolders should be nil when column is absent"
        )
        #expect(
            carPlayConfig?.resolvedShowAddEditButtons == true,
            "CarPlay config should show Add/Edit buttons by default"
        )
    }

    @Test func showAddEditButtonsDefaultsToVisible() {
        #expect(CarPlayConfig().showAddEditButtons == nil)
        #expect(CarPlayConfig().resolvedShowAddEditButtons == true)
        #expect(CarPlayConfig(showAddEditButtons: false).resolvedShowAddEditButtons == false)
        #expect(CarPlayConfig(showAddEditButtons: true).resolvedShowAddEditButtons == true)
    }

    @Test func carPlayTabRawValueRoundTrip() {
        #expect(CarPlayTab(rawValue: "quickAccess") == .quickAccess)
        #expect(CarPlayTab(rawValue: "areas") == .areas)
        #expect(CarPlayTab(rawValue: "domains") == .domains)
        #expect(CarPlayTab(rawValue: "settings") == .settings)
        #expect(CarPlayTab(rawValue: "folder:abc") == .folder(folderId: "abc"))
        #expect(CarPlayTab(rawValue: "bogus") == nil)
        #expect(CarPlayTab.folder(folderId: "abc").rawValue == "folder:abc")
        #expect(CarPlayTab.folder(folderId: "abc").folderId == "abc")
        #expect(CarPlayTab.quickAccess.folderId == nil)
    }

    @Test func carPlayTabCodableKeepsLegacyStringEncoding() throws {
        // Configs persisted before folder tabs existed encode tabs as plain strings.
        let legacyJSON = Data(#"["quickAccess","areas","settings"]"#.utf8)
        let decoded = try JSONDecoder().decode([CarPlayTab].self, from: legacyJSON)
        #expect(decoded == [.quickAccess, .areas, .settings])

        let tabs: [CarPlayTab] = [.quickAccess, .folder(folderId: "abc"), .settings]
        let encoded = try JSONEncoder().encode(tabs)
        #expect(String(data: encoded, encoding: .utf8) == #"["quickAccess","folder:abc","settings"]"#)
        #expect(try JSONDecoder().decode([CarPlayTab].self, from: encoded) == tabs)
    }

    @Test func folderHelpersResolveFoldersAndNames() {
        let folder = MagicItem(id: "folder-1", serverId: "", type: .folder, displayText: "Garage", items: [])
        let config = CarPlayConfig(
            tabs: [.quickAccess, .folder(folderId: "folder-1")],
            quickAccessItems: [folder]
        )
        #expect(config.folders == [folder])
        #expect(config.folder(withId: "folder-1")?.id == "folder-1")
        #expect(config.folder(withId: "missing") == nil)
        #expect(config.name(for: .folder(folderId: "folder-1")) == "Garage")
        #expect(config.name(for: .folder(folderId: "missing")) == CarPlayTab.folder(folderId: "missing").name)
        #expect(config.name(for: .quickAccess) == CarPlayTab.quickAccess.name)
    }

    @Test func tabOnlyFoldersResolveLikeQuickAccessFolders() {
        let quickAccessFolder = MagicItem(id: "qa-folder", serverId: "", type: .folder, displayText: "Garage")
        let tabFolder = MagicItem(id: "tab-folder", serverId: "", type: .folder, displayText: "Commute")
        let config = CarPlayConfig(
            tabs: [.quickAccess, .folder(folderId: "tab-folder")],
            quickAccessItems: [quickAccessFolder],
            tabFolders: [tabFolder]
        )
        // Tab-only folders resolve for tabs, but stay out of the Quick Access folder list.
        #expect(config.folders == [quickAccessFolder])
        #expect(config.allFolders == [quickAccessFolder, tabFolder])
        #expect(config.folder(withId: "tab-folder")?.id == "tab-folder")
        #expect(config.name(for: .folder(folderId: "tab-folder")) == "Commute")
    }
}
