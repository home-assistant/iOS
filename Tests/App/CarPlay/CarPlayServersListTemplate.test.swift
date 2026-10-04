import CarPlay
import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The CarPlay settings tab: the rows it lists, what each one shows, and that tapping them opens
/// their picker or applies the change.
final class CarPlayServersListTemplateTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousPreferredServer: Any?
    private var database: DatabaseQueue!
    private var servers: FakeServerManager!
    private var viewModel: CarPlayServerListViewModel!
    private var sut: CarPlayServersListTemplate!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database
        previousPreferredServer = prefs.object(forKey: CarPlayPreferredServer.preferenceKey)

        let database = try CarPlayTestHelpers.makeDatabase()
        self.database = database
        Current.database = { database }
        servers = FakeServerManager()
        Current.servers = servers
        servers.addFake()
        prefs.removeObject(forKey: CarPlayPreferredServer.preferenceKey)

        viewModel = CarPlayServerListViewModel()
        sut = CarPlayServersListTemplate(viewModel: viewModel)
    }

    override func tearDown() {
        Current.servers = previousServers
        Current.database = previousDatabase
        if let previousPreferredServer {
            prefs.set(previousPreferredServer, forKey: CarPlayPreferredServer.preferenceKey)
        } else {
            prefs.removeObject(forKey: CarPlayPreferredServer.preferenceKey)
        }
        sut = nil
        viewModel = nil
        servers = nil
        database = nil
        super.tearDown()
    }

    private var rows: [CPListItem] {
        CarPlayTestHelpers.listItems(of: sut.template)
    }

    private func row(titled title: String) throws -> CPListItem {
        try XCTUnwrap(rows.first(where: { $0.text == title }), "No row titled \(title)")
    }

    func testTheTabIsTheSettingsTab() {
        XCTAssertEqual(sut.template.tabTitle, L10n.CarPlay.Labels.Tab.settings)
        XCTAssertNotNil(sut.template.tabImage)
        XCTAssertTrue(sut.template.sections.isEmpty, "Rows are only built once the tab appears")
        XCTAssertTrue(CarPlayServersListTemplate.build() is CarPlayServersListTemplate)
    }

    func testAppearingListsEverySetting() {
        sut.templateWillAppear(template: sut.template)

        XCTAssertEqual(rows.map(\.text), [
            L10n.CarPlay.Labels.Settings.MainServer.title,
            L10n.Carplay.Tab.QuickAccess.layout,
            L10n.CarPlay.Config.Tabs.title,
            L10n.CarPlay.Config.QuickAccess.ShowAddEditButtons.title,
            L10n.Assist.Settings.title,
            L10n.CarPlay.Labels.Settings.Troubleshooting.title,
        ])
        XCTAssertEqual(rows.first?.detailText, "Fake Server")
        XCTAssertEqual(rows[1].detailText, CarPlayQuickAccessLayout.grid.name)
        XCTAssertEqual(rows[2].detailText, viewModel.tabsSummary)
    }

    /// The tab follows server changes only while it is on screen.
    func testServerChangesAreObservedWhileTheTabIsOnScreen() {
        sut.templateWillAppear(template: sut.template)
        XCTAssertEqual(servers.observers.count, 1)

        sut.templateWillDisappear(template: sut.template)
        XCTAssertTrue(servers.observers.isEmpty)
    }

    /// Another template appearing or disappearing is not this tab's business.
    func testOtherTemplatesDoNotRebuildTheTab() {
        let other = CPListTemplate(title: "Other", sections: [])

        sut.templateWillAppear(template: other)
        sut.templateWillDisappear(template: other)

        XCTAssertTrue(sut.template.sections.isEmpty)
        XCTAssertTrue(servers.observers.isEmpty)
    }

    func testTappingAddEditRowsTogglesTheSetting() throws {
        sut.update()
        let toggle = try row(titled: L10n.CarPlay.Config.QuickAccess.ShowAddEditButtons.title)
        XCTAssertNotNil(toggle.image, "Shown by default, so the row carries a check")

        CarPlayTestHelpers.tap(toggle)

        XCTAssertFalse(viewModel.showAddEditButtons)
        XCTAssertEqual(try CarPlayTestHelpers.storedConfig(in: database)?.showAddEditButtons, false)
        let refreshed = try row(titled: L10n.CarPlay.Config.QuickAccess.ShowAddEditButtons.title)
        XCTAssertNil(refreshed.image)
    }

    /// Without a CarPlay screen the pickers have nowhere to go, but opening them must not change
    /// anything until a choice is made.
    func testOpeningEachPickerChangesNothing() throws {
        sut.update()

        try CarPlayTestHelpers.tap(row(titled: L10n.CarPlay.Labels.Settings.MainServer.title))
        try CarPlayTestHelpers.tap(row(titled: L10n.Carplay.Tab.QuickAccess.layout))
        try CarPlayTestHelpers.tap(row(titled: L10n.CarPlay.Config.Tabs.title))
        try CarPlayTestHelpers.tap(row(titled: L10n.Assist.Settings.title))
        try CarPlayTestHelpers.tap(row(titled: L10n.CarPlay.Labels.Settings.Troubleshooting.title))
        CarPlayTestHelpers.drainMainQueue(self)

        XCTAssertNil(try CarPlayTestHelpers.storedConfig(in: database))
        XCTAssertNil(prefs.string(forKey: CarPlayPreferredServer.preferenceKey))
        XCTAssertEqual(rows.count, 6)
    }

    func testStateChangesDoNotTouchTheTab() throws {
        sut.update()
        let before = rows.map(\.text)

        let states = try CarPlayTestHelpers.states([CarPlayTestHelpers.entity("light.kitchen")])
        sut.entitiesStateChange(serverId: "server", entities: states)

        XCTAssertEqual(rows.map(\.text), before)
    }

    /// No server at all: the no-server alert has nowhere to show without a CarPlay screen, and
    /// asking for it must not crash.
    func testAskingForTheNoServerAlertWithoutAScreenDoesNothing() {
        sut.showNoServerAlert()

        XCTAssertTrue(sut.template.sections.isEmpty)
    }
}
