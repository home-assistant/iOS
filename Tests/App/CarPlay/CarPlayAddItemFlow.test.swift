import CarPlay
import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The in-car "Add item" flow: one list that steps through server → category → area or domain →
/// entity, with a Back row on every step but the first.
final class CarPlayAddItemFlowTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var database: DatabaseQueue!
    private var servers: FakeServerManager!
    private var finishCount = 0
    private var sut: CarPlayAddItemFlow!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database

        let database = try CarPlayTestHelpers.makeDatabase()
        self.database = database
        Current.database = { database }
        servers = FakeServerManager()
        Current.servers = servers
        finishCount = 0
    }

    override func tearDown() {
        Current.servers = previousServers
        Current.database = previousDatabase
        sut = nil
        servers = nil
        database = nil
        super.tearDown()
    }

    @discardableResult
    private func addSeededServer() throws -> Server {
        let server = servers.addFake()
        try CarPlayAddItemFixture.seed(in: database, serverId: server.identifier.rawValue)
        return server
    }

    private func start(destination: CarPlayAddItemViewModel.Destination = .quickAccess) {
        sut = CarPlayAddItemFlow(
            interfaceController: nil,
            viewModel: CarPlayAddItemViewModel(destination: destination),
            onFinish: { [weak self] in self?.finishCount += 1 }
        )
        sut.start()
    }

    private var template: CPListTemplate {
        get throws {
            let flow = try XCTUnwrap(sut)
            return try XCTUnwrap(CarPlayTestHelpers.listTemplate(named: "template", of: flow))
        }
    }

    /// The step's own rows, without the Back row.
    private func contentRows() throws -> [CPListItem] {
        try XCTUnwrap(template.sections.last?.items.compactMap { $0 as? CPListItem })
    }

    private func contentTexts() throws -> [String] {
        try contentRows().compactMap(\.text)
    }

    private func tapContentRow(_ text: String) throws {
        let row = try XCTUnwrap(contentRows().first(where: { $0.text == text }), "No row titled \(text)")
        CarPlayTestHelpers.tap(row)
    }

    private func tapBack() throws {
        let section = try XCTUnwrap(template.sections.first)
        let back = try XCTUnwrap(section.items.first as? CPListItem)
        XCTAssertEqual(back.text, L10n.CarPlay.QuickAccess.AddItem.back)
        CarPlayTestHelpers.tap(back)
    }

    // MARK: - Starting

    func testStartingWithoutAServerEndsTheFlowRightAway() throws {
        start()

        XCTAssertEqual(finishCount, 1)
        XCTAssertTrue(try template.sections.isEmpty)
    }

    /// With one server there's nothing to choose, so the flow opens on that server's categories.
    func testASingleServerOpensOnItsCategories() throws {
        let server = try addSeededServer()

        start()

        XCTAssertEqual(try template.sections.count, 1, "The first step has no Back row")
        XCTAssertEqual(try template.sections.first?.header, server.info.name)
        let texts = try contentTexts()
        XCTAssertEqual(Array(texts.prefix(3)), [
            L10n.CarPlay.Navigation.Tab.areas,
            L10n.CarPlay.Navigation.Tab.domains,
            L10n.Watch.Configuration.Folder.defaultName,
        ])
        if #available(iOS 26.4, *) {
            XCTAssertEqual(texts.count, 5)
        } else {
            XCTAssertEqual(texts.count, 3)
        }
    }

    /// Folders can't hold folders, so adding into one doesn't offer creating another.
    func testAddingIntoAFolderDoesNotOfferFolders() throws {
        try addSeededServer()

        start(destination: .folder(folderId: "garage"))

        XCTAssertFalse(try contentTexts().contains(L10n.Watch.Configuration.Folder.defaultName))
        XCTAssertTrue(try contentTexts().contains(L10n.CarPlay.Navigation.Tab.areas))
    }

    func testSeveralServersStartWithChoosingOne() throws {
        try addSeededServer()
        servers.addFake()

        start()

        XCTAssertEqual(try template.sections.first?.header, L10n.CarPlay.Labels.selectServer)
        XCTAssertEqual(try contentTexts(), ["Fake Server", "Fake Server"])

        try CarPlayTestHelpers.tap(XCTUnwrap(contentRows().first))
        XCTAssertEqual(try template.sections.count, 2)
        XCTAssertEqual(try contentTexts().first, L10n.CarPlay.Navigation.Tab.areas)

        try tapBack()
        XCTAssertEqual(try template.sections.count, 1)
        XCTAssertEqual(try template.sections.first?.header, L10n.CarPlay.Labels.selectServer)
        XCTAssertEqual(finishCount, 0)
    }

    // MARK: - Browsing

    func testBrowsingAnAreaListsWhatCanBeAdded() throws {
        try addSeededServer()
        start()

        try tapContentRow(L10n.CarPlay.Navigation.Tab.areas)
        XCTAssertEqual(try template.sections.last?.header, L10n.CarPlay.Navigation.Tab.areas)
        XCTAssertEqual(try contentTexts(), ["Kitchen", "Garage"])

        try tapContentRow("Garage")
        XCTAssertEqual(try template.sections.last?.header, "Garage")
        XCTAssertEqual(try contentTexts(), ["Front door", "Garage door"])

        // Locks always confirm when run, so the flow doesn't ask and adds the lock straight away;
        // the save waits for CarPlay's pop transition, which needs a CarPlay screen.
        try tapContentRow("Front door")
        try tapContentRow("Garage door")
        XCTAssertNil(try CarPlayTestHelpers.storedConfig(in: database))

        try tapBack()
        XCTAssertEqual(try contentTexts(), ["Kitchen", "Garage"])
        try tapBack()
        XCTAssertEqual(try template.sections.count, 1)
        XCTAssertEqual(finishCount, 0)
    }

    func testBrowsingADomainListsItsEntities() throws {
        try addSeededServer()
        start()

        try tapContentRow(L10n.CarPlay.Navigation.Tab.domains)
        XCTAssertEqual(try contentTexts().first, Domain.cover.localizedDescription)
        XCTAssertEqual(try contentTexts().count, 4)

        try tapContentRow(Domain.climate.localizedDescription)
        XCTAssertEqual(try contentTexts(), ["Hall thermostat"])
        try tapContentRow("Hall thermostat")

        try tapBack()
        try tapContentRow(Domain.light.localizedDescription)
        XCTAssertEqual(try contentTexts(), ["Kitchen light"])
        try tapContentRow("Kitchen light")
        XCTAssertNil(try CarPlayTestHelpers.storedConfig(in: database))
    }

    /// A server with nothing cached says so rather than showing an empty list.
    func testAServerWithNothingCachedSaysSo() throws {
        servers.addFake()
        start()

        try tapContentRow(L10n.CarPlay.Navigation.Tab.areas)
        XCTAssertEqual(try contentTexts(), [L10n.CarPlay.Labels.emptyAreaList])

        try tapBack()
        try tapContentRow(L10n.CarPlay.Navigation.Tab.domains)
        XCTAssertEqual(try contentTexts(), [L10n.CarPlay.Labels.emptyDomainList])
    }

    func testTheFolderAndPromptRowsOnlyExplain() throws {
        try addSeededServer()
        start()

        try tapContentRow(L10n.Watch.Configuration.Folder.defaultName)
        if #available(iOS 26.4, *) {
            try tapContentRow(L10n.MagicItem.ItemType.AssistPrompt.title)
        }

        XCTAssertEqual(try template.sections.count, 1, "Neither opens a step of its own")
        XCTAssertNil(try CarPlayTestHelpers.storedConfig(in: database))
    }

    func testBrowsingAssistListsTheServersPipelines() throws {
        guard #available(iOS 26.4, *) else {
            throw XCTSkip("Assist in CarPlay needs iOS 26.4")
        }
        try addSeededServer()
        start()

        try tapContentRow(L10n.Widgets.Action.Name.assist)

        XCTAssertEqual(try contentTexts(), [L10n.AppIntents.Assist.PreferredPipeline.title, "Home", "Local"])
        try tapContentRow("Local")
        XCTAssertNil(try CarPlayTestHelpers.storedConfig(in: database))
    }
}
