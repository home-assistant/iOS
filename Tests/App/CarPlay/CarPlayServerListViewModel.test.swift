import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The settings tab's choices: which server CarPlay follows, which tabs it shows, the Quick Access
/// layout and the Add/Edit rows. Every choice is staged while its picker is open and only saved
/// when the picker closes.
final class CarPlayServerListViewModelTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousPreferredServer: Any?
    private var previousDebugSettings: CarPlayAssistDebugSettings!
    private var database: DatabaseQueue!
    private var servers: FakeServerManager!
    private var sut: CarPlayServerListViewModel!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database
        previousPreferredServer = prefs.object(forKey: CarPlayPreferredServer.preferenceKey)
        previousDebugSettings = Current.settingsStore.carPlayAssistDebugSettings

        let database = try CarPlayTestHelpers.makeDatabase()
        self.database = database
        Current.database = { database }
        servers = FakeServerManager()
        Current.servers = servers
        prefs.removeObject(forKey: CarPlayPreferredServer.preferenceKey)
        sut = CarPlayServerListViewModel()
    }

    override func tearDown() {
        Current.servers = previousServers
        Current.database = previousDatabase
        Current.settingsStore.carPlayAssistDebugSettings = previousDebugSettings
        if let previousPreferredServer {
            prefs.set(previousPreferredServer, forKey: CarPlayPreferredServer.preferenceKey)
        } else {
            prefs.removeObject(forKey: CarPlayPreferredServer.preferenceKey)
        }
        sut = nil
        servers = nil
        database = nil
        super.tearDown()
    }

    private func storedConfig() throws -> CarPlayConfig? {
        try CarPlayTestHelpers.storedConfig(in: database)
    }

    // MARK: - Tabs

    func testTabsDefaultWhenNothingIsStored() {
        XCTAssertEqual(sut.tabs, [.quickAccess, .areas, .settings])
    }

    /// Settings is how the driver gets back to these choices, so it is always there, and always last.
    func testStoredTabsAlwaysEndWithSettings() throws {
        try CarPlayTestHelpers.save(CarPlayConfig(tabs: [.settings, .domains]), in: database)

        XCTAssertEqual(sut.tabs, [.domains, .settings])
    }

    func testTabChangesAreSavedWhenThePickerCloses() throws {
        sut.beginTabSelection()
        sut.setTab(.domains, active: true)
        sut.setTab(.areas, active: false)

        XCTAssertTrue(sut.isTabActive(.domains))
        XCTAssertFalse(sut.isTabActive(.areas))
        XCTAssertNil(try storedConfig(), "Nothing is saved while the picker is open")

        sut.commitTabSelection()

        XCTAssertEqual(try storedConfig()?.tabs, [.quickAccess, .domains, .settings])
        XCTAssertEqual(sut.tabs, [.quickAccess, .domains, .settings])
    }

    func testActivatingATabTwiceAddsItOnce() {
        sut.beginTabSelection()
        sut.setTab(.domains, active: true)
        sut.setTab(.domains, active: true)
        sut.commitTabSelection()

        XCTAssertEqual(sut.tabs, [.quickAccess, .areas, .domains, .settings])
    }

    func testTheSettingsTabCannotBeSwitchedOff() {
        sut.beginTabSelection()
        sut.setTab(.settings, active: false)

        XCTAssertTrue(sut.isTabActive(.settings))
    }

    /// Closing the picker without changing anything leaves the stored configuration alone.
    func testClosingTheTabPickerWithoutChangesSavesNothing() throws {
        sut.commitTabSelection()
        sut.beginTabSelection()
        sut.commitTabSelection()

        XCTAssertNil(try storedConfig())
    }

    /// Folders created as tabs exist only to back their tab, so switching the tab off deletes them.
    func testSwitchingOffAFolderTabDeletesItsTabOnlyFolder() throws {
        let tabFolder = MagicItem(id: "commute", serverId: "", type: .folder, displayText: "Commute", items: [])
        try CarPlayTestHelpers.save(
            CarPlayConfig(tabs: [.quickAccess, .folder(folderId: "commute"), .settings], tabFolders: [tabFolder]),
            in: database
        )

        sut.beginTabSelection()
        XCTAssertTrue(sut.isTabActive(.folder(folderId: "commute")))
        sut.setTab(.folder(folderId: "commute"), active: false)
        sut.commitTabSelection()

        let stored = try XCTUnwrap(try storedConfig())
        XCTAssertEqual(stored.tabs, [.quickAccess, .settings])
        XCTAssertEqual(stored.tabFolders, [])
    }

    func testTabsSummaryNamesFolderTabsByTheirFolder() throws {
        let tabFolder = MagicItem(id: "commute", serverId: "", type: .folder, displayText: "Commute", items: [])
        try CarPlayTestHelpers.save(
            CarPlayConfig(tabs: [.quickAccess, .folder(folderId: "commute"), .settings], tabFolders: [tabFolder]),
            in: database
        )

        XCTAssertEqual(
            sut.tabsSummary,
            [CarPlayTab.quickAccess.name, "Commute", CarPlayTab.settings.name].joined(separator: ", ")
        )
    }

    func testEveryFolderCanBecomeATab() throws {
        let quickAccessFolder = MagicItem(id: "garage", serverId: "", type: .folder, displayText: "Garage")
        let tabFolder = MagicItem(id: "commute", serverId: "", type: .folder, displayText: "Commute")
        try CarPlayTestHelpers.save(
            CarPlayConfig(quickAccessItems: [quickAccessFolder], tabFolders: [tabFolder]),
            in: database
        )

        XCTAssertEqual(sut.tabFolderItems.map(\.id), ["garage", "commute"])
        XCTAssertEqual(
            sut.selectableTabs,
            CarPlayTab.allCases + [.folder(folderId: "garage"), .folder(folderId: "commute")]
        )
    }

    // MARK: - Quick Access layout

    func testAnEmptyQuickAccessDefaultsToTheGrid() {
        XCTAssertEqual(sut.quickAccessLayout, .grid)
    }

    func testLayoutChangeIsSavedWhenThePickerCloses() throws {
        sut.beginLayoutSelection()
        XCTAssertTrue(sut.isLayoutActive(.grid))

        sut.setLayout(.list)
        XCTAssertTrue(sut.isLayoutActive(.list))
        XCTAssertFalse(sut.isLayoutActive(.grid))
        XCTAssertNil(try storedConfig())

        sut.commitLayoutSelection()

        XCTAssertEqual(try storedConfig()?.quickAccessLayout, .list)
        XCTAssertEqual(sut.quickAccessLayout, .list)
    }

    func testClosingTheLayoutPickerWithoutChangesSavesNothing() throws {
        sut.commitLayoutSelection()
        sut.beginLayoutSelection()
        sut.setLayout(.grid)
        sut.commitLayoutSelection()

        XCTAssertNil(try storedConfig())
    }

    // MARK: - Add/Edit rows

    func testAddEditRowsAreShownByDefaultAndToggle() throws {
        XCTAssertTrue(sut.showAddEditButtons)

        sut.toggleShowAddEditButtons()
        XCTAssertFalse(sut.showAddEditButtons)
        XCTAssertEqual(try storedConfig()?.showAddEditButtons, false)

        sut.toggleShowAddEditButtons()
        XCTAssertTrue(sut.showAddEditButtons)
    }

    // MARK: - Main server

    func testServerSelectionIsSavedWhenThePickerCloses() {
        let first = servers.addFake()
        let second = servers.addFake()

        sut.beginServerSelection()
        XCTAssertTrue(sut.isServerActive(first), "Without a choice CarPlay follows the first server")
        XCTAssertFalse(sut.isServerActive(second))

        sut.setServer(second)
        XCTAssertTrue(sut.isServerActive(second))
        XCTAssertNil(prefs.string(forKey: CarPlayPreferredServer.preferenceKey))

        sut.commitServerSelection()

        XCTAssertEqual(CarPlayPreferredServer.id, second.identifier.rawValue)
        XCTAssertEqual(CarPlayPreferredServer.current?.identifier, second.identifier)
    }

    func testPickingTheServerAlreadyInUseSavesNothing() {
        let first = servers.addFake()
        servers.addFake()

        sut.commitServerSelection()
        sut.beginServerSelection()
        sut.setServer(first)
        sut.commitServerSelection()

        XCTAssertNil(prefs.string(forKey: CarPlayPreferredServer.preferenceKey))
    }

    // MARK: - Server changes

    func testObservesServerChangesOnlyWhileAsked() {
        sut.addServerObserver()
        sut.addServerObserver()
        XCTAssertEqual(servers.observers.count, 1)

        sut.removeServerObserver()
        XCTAssertTrue(servers.observers.isEmpty)
    }

    /// When the chosen server goes away, CarPlay moves to whichever one is left.
    func testAServerChangeFallsBackToAnAvailableServer() {
        let remaining = servers.addFake()
        prefs.set("gone", forKey: CarPlayPreferredServer.preferenceKey)
        let template = CarPlayServersListTemplate(viewModel: sut)

        sut.serversDidChange(servers)

        XCTAssertEqual(CarPlayPreferredServer.id, remaining.identifier.rawValue)
        XCTAssertEqual(template.template.sections.count, 1)
    }

    func testLosingEveryServerLeavesTheSelectionAlone() {
        let template = CarPlayServersListTemplate(viewModel: sut)

        sut.serversDidChange(servers)

        XCTAssertNil(prefs.string(forKey: CarPlayPreferredServer.preferenceKey))
        XCTAssertTrue(template.template.sections.isEmpty)
    }

    // MARK: - Assist audio

    func testAssistAudioStrategyIsSaved() {
        sut.setTTSPlaybackStrategy(.downloadedAVAudioPlayer)
        XCTAssertEqual(sut.ttsPlaybackStrategy, .downloadedAVAudioPlayer)

        sut.setTTSPlaybackStrategy(.avPlayer)
        XCTAssertEqual(sut.ttsPlaybackStrategy, .avPlayer)
    }

    // MARK: - Unreadable configuration

    /// A database the app can't read falls back to the defaults rather than leaving the car with
    /// no tabs.
    func testAnUnreadableConfigurationFallsBackToDefaults() throws {
        let broken = try DatabaseQueue()
        Current.database = { broken }

        XCTAssertEqual(sut.tabs, [.quickAccess, .areas, .settings])
        XCTAssertEqual(sut.tabFolderItems, [])
        XCTAssertEqual(sut.quickAccessLayout, .grid)
        XCTAssertTrue(sut.showAddEditButtons)

        sut.beginTabSelection()
        sut.setTab(.domains, active: true)
        sut.commitTabSelection()
        sut.beginLayoutSelection()
        sut.setLayout(.list)
        sut.commitLayoutSelection()
        sut.toggleShowAddEditButtons()

        XCTAssertEqual(sut.tabs, [.quickAccess, .areas, .settings])
    }
}
