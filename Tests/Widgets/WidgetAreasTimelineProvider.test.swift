@testable import HomeAssistant

import GRDB
@testable import Shared
import Testing
import WidgetKit

/// What the widget's timeline is built from: the areas the app has already stored, the page the
/// widget was left on, and the server it was configured with.
@Suite(.serialized)
struct WidgetAreasTimelineProviderTests {
    @available(iOS 17, *)
    @Test func aServersAreasBecomeThePageTheWidgetDraws() throws {
        try withServerAndAreas(count: 3) { serverId in
            AppPanel.setAreasDashboardPath("rooms", serverId: serverId)
            let entry = WidgetAreasTimelineProvider().entry(
                for: configuration(serverId: serverId),
                family: .systemMedium
            )
            #expect(entry.pageCount == 1)
            #expect(entry.page.sections.flatMap(\.areas).map(\.name) == ["Area 0", "Area 1", "Area 2"])
            #expect(entry.serverId == serverId)
            #expect(entry.serverName == "Fake Server")
            #expect(entry.dashboardPath == "rooms")
        }
    }

    /// A widget whose server has gone away draws the empty state rather than the areas of whatever
    /// server is left.
    @available(iOS 17, *)
    @Test func aWidgetWhoseServerIsGoneIsEmpty() throws {
        try withServerAndAreas(count: 3) { _ in
            let entry = WidgetAreasTimelineProvider().entry(
                for: configuration(serverId: "gone"),
                family: .systemMedium
            )
            #expect(entry.pageCount == 0)
            #expect(entry.page.sections.isEmpty)
            #expect(entry.serverId == nil)
        }
    }

    @available(iOS 17, *)
    @Test func theWidgetOpensOnThePageItWasLeftOn() throws {
        try withServerAndAreas(count: 9) { serverId in
            WidgetAreasPageStore.setPage(1, serverId: serverId, family: .systemMedium)
            let entry = WidgetAreasTimelineProvider().entry(
                for: configuration(serverId: serverId),
                family: .systemMedium
            )
            #expect(entry.pageCount == 3)
            #expect(entry.page.id == 1)
            #expect(entry.page.sections.flatMap(\.areas).map(\.name) == ["Area 4", "Area 5", "Area 6", "Area 7"])
        }
    }

    /// A page the areas under it have outlived lands on the last page there is.
    @available(iOS 17, *)
    @Test func aStoredPageThatNoLongerExistsFallsBackToTheLastOne() throws {
        try withServerAndAreas(count: 3) { serverId in
            WidgetAreasPageStore.setPage(7, serverId: serverId, family: .systemMedium)
            let entry = WidgetAreasTimelineProvider().entry(
                for: configuration(serverId: serverId),
                family: .systemMedium
            )
            #expect(entry.page.id == 0)
            #expect(entry.pageCount == 1)
        }
    }

    /// Areas change about as often as the home is rearranged, so the widget asks for little.
    /// A database that cannot answer — a widget woken while the app is still setting it up — draws
    /// the empty state rather than a half-built page.
    @available(iOS 17, *)
    @Test func aDatabaseThatCannotAnswerDrawsNothing() throws {
        try withServerAndAreas(count: 0, tables: false) { serverId in
            let entry = WidgetAreasTimelineProvider().entry(
                for: configuration(serverId: serverId),
                family: .systemMedium
            )
            #expect(entry.pageCount == 0)
            #expect(entry.serverId == serverId)
        }
    }

    @available(iOS 17, *)
    @Test func theTimelineExpiresInAnHour() {
        #expect(WidgetAreasTimelineProvider().expiration.value == 60)
        #expect(WidgetAreasTimelineProvider().expiration.unit == .minutes)
    }

    /// The placeholder has nothing to draw, and the gallery's entry is the sample home.
    @available(iOS 17, *)
    @Test func placeholderAndPreviewEntries() {
        #expect(WidgetAreasEntry.empty().pageCount == 0)
        #expect(WidgetAreasEntry.empty().serverId == nil)
        let preview = WidgetAreasEntry.preview(family: .systemLarge)
        #expect(preview.pageCount > 1)
        #expect(preview.serverName == "Home")
        #expect(preview.page.sections.first?.title == "Ground floor")
        // Off the end of the sample home, so the gallery never draws a half-built page.
        #expect(WidgetAreasEntry.preview(family: .systemLarge, page: 9).page.sections.isEmpty)
    }

    /// Every system family, the portrait extra-large one included, so the widget is in the gallery
    /// at every size the home screen offers it.
    @available(iOS 17, *)
    @Test func theWidgetIsConfiguredWithAServerAndSupportsEverySystemSize() async throws {
        #expect(
            WidgetAreasSupportedFamilies.families ==
                [.systemSmall, .systemMedium, .systemLarge] + WidgetFamily.extraLarges
        )
        _ = WidgetAreas().body
        _ = WidgetAreasAppIntent.parameterSummary
        _ = try await WidgetAreasAppIntent().perform()
    }

    @available(iOS 17, *)
    private func configuration(serverId: String) -> WidgetAreasAppIntent {
        let configuration = WidgetAreasAppIntent()
        configuration.server = IntentServerAppEntity(identifier: .init(rawValue: serverId))
        return configuration
    }

    /// Points `Current` at a fresh in-memory database holding `count` areas of one fake server, and
    /// at that server, so the provider reads the test's home rather than the machine's.
    private func withServerAndAreas(
        count: Int,
        servers: Int = 1,
        tables: Bool = true,
        _ body: (String) throws -> Void
    ) throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        let manager = FakeServerManager(initial: servers)
        Current.servers = manager
        let database = try DatabaseQueue()
        if tables {
            for table in DatabaseQueue.tables() {
                try table.createIfNeeded(database: database)
            }
        }
        Current.database = { database }

        let serverId = manager.all.first?.identifier.rawValue ?? "no-server"
        try database.write { db in
            guard tables else { return }
            for index in 0 ..< count {
                try AppArea(
                    id: "\(serverId)-area\(index)",
                    serverId: serverId,
                    areaId: "area\(index)",
                    name: "Area \(index)",
                    aliases: [],
                    picture: nil,
                    icon: nil,
                    sortOrder: index,
                    entities: []
                ).insert(db)
            }
        }

        WidgetAreasPageStore.setPage(0, serverId: serverId, family: .systemMedium)
        try body(serverId)
    }
}
