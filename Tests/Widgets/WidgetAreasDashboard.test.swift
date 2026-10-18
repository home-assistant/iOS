import Foundation
import HAKit
import HAKit_Mocks
@testable import Shared
import Testing

/// Where an area tile lands: the view the frontend opens when an area is tapped, `areas-<area_id>`
/// under the dashboard that has a view for every area.
@Suite(.serialized)
struct WidgetAreasDashboardTests {
    private static func panel(_ path: String, component: String) -> HAPanel {
        .init(icon: nil, title: path.capitalized, path: path, component: component, showInSidebar: true)
    }

    private static func panels(_ panels: [HAPanel]) -> HAPanels {
        .init(panelsByPath: Dictionary(panels.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first }))
    }

    /// Core registers the built-in dashboard as a panel of its own — component `home`, not
    /// `lovelace` — and that is the one that always has a view per area.
    @Test func theBuiltInDashboardIsTheOneWithAreaViews() {
        let panels = Self.panels([
            Self.panel("home", component: "home"),
            Self.panel("lovelace", component: "lovelace"),
            Self.panel("energy", component: "energy"),
        ])
        #expect(AppPanel.homeDashboardPath(in: panels) == "home")
        #expect(AppPanel.resolveAreasDashboardPath(panels: panels, strategies: [:]) == "home")
    }

    /// A server without it may still have a dashboard the areas strategy builds, which has the same
    /// views under a path of the user's choosing.
    @Test func anAreasStrategyDashboardStandsInForIt() {
        let panels = Self.panels([
            Self.panel("lovelace", component: "lovelace"),
            Self.panel("rooms", component: "lovelace"),
        ])
        #expect(AppPanel.homeDashboardPath(in: panels) == nil)
        #expect(AppPanel.resolveAreasDashboardPath(
            panels: panels,
            strategies: ["lovelace": "original-states", "rooms": "areas"]
        ) == "rooms")
    }

    /// A server with neither has nowhere to open an area on a dashboard.
    @Test func aServerWithNeitherHasNoAreasDashboard() {
        let panels = Self.panels([Self.panel("lovelace", component: "lovelace")])
        #expect(AppPanel.resolveAreasDashboardPath(panels: panels, strategies: [:]) == nil)
    }

    /// Nothing stored and no panels known — a widget dropped before the app has talked to the
    /// server — has nowhere to point yet either.
    @Test func anUnknownServerHasNoAreasDashboard() {
        #expect(AppPanel.areasDashboardPath(serverId: "never-seen") == nil)
    }

    @Test func theResolvedDashboardIsKeptForTheWidgetsToRead() {
        AppPanel.setAreasDashboardPath("rooms", serverId: "stored-server")
        #expect(AppPanel.areasDashboardPath(serverId: "stored-server") == "rooms")
        AppPanel.setAreasDashboardPath(nil, serverId: "stored-server")
        #expect(AppPanel.areasDashboardPath(serverId: "stored-server") == nil)
    }

    /// The built-in dashboard settles it without asking anything, which is what keeps a panel
    /// refresh from costing a round trip per dashboard on almost every server.
    @Test func theBuiltInDashboardCostsNoRequests() async {
        let connection = HAMockConnection()
        let serverId = "built-in-server"
        AppPanel.setAreasDashboardPath("rooms", serverId: serverId)
        await AppPanel.updateAreasDashboard(
            panels: Self.panels([Self.panel("home", component: "home")]),
            serverId: serverId,
            on: connection
        )
        #expect(connection.pendingRequests.isEmpty)
        // Nothing kept: the widget reads the built-in dashboard out of the stored panels.
        #expect(AppPanel.areasDashboardPath(serverId: serverId) == nil)
    }

    /// The round trip on an older server: each dashboard is asked what builds it, and the one the
    /// areas strategy builds is what gets stored.
    @Test func theStrategyEachDashboardReportsIsWhatGetsStored() async {
        let connection = HAMockConnection()
        let serverId = "round-trip-server"
        let update = Task {
            await AppPanel.updateAreasDashboard(
                panels: Self.panels([
                    Self.panel("lovelace", component: "lovelace"),
                    Self.panel("rooms", component: "lovelace"),
                ]),
                serverId: serverId,
                on: connection
            )
        }
        // The default dashboard is addressed by a null path, and answers with no strategy at all.
        await answer(connection, request: 0, with: ["views": []])
        await answer(connection, request: 1, with: ["strategy": ["type": "areas"]])
        await update.value

        #expect(AppPanel.areasDashboardPath(serverId: serverId) == "rooms")
        let firstRequest = connection.pendingRequests.first?.request.data["url_path"]
        #expect(firstRequest is NSNull)
    }

    /// A dashboard that has never been edited has no stored config and answers with an error, which
    /// reads as "not built by a strategy" rather than as a failure.
    @Test func aDashboardWithoutAConfigReportsNoStrategy() async {
        let connection = HAMockConnection()
        let strategy = Task { await AppPanel.dashboardStrategy(on: connection, path: "rooms") }
        await failRequest(connection, request: 0)
        let resolved = await strategy.value
        #expect(resolved == nil)
    }

    @Test func theDeepLinkPointsAtTheAreasViewOfThatDashboard() throws {
        let url = try #require(AppConstants.openAreaDeeplinkURL(
            areaId: "living_room",
            serverId: "server-1",
            dashboardPath: "home"
        ))
        #expect(url.absoluteString.contains("navigate/home/areas-living_room"))
        #expect(url.absoluteString.contains("server=server-1"))
    }

    /// With no dashboard to open the area on, the tile opens it in Settings rather than nowhere.
    @Test func anAreaWithoutADashboardOpensInSettings() throws {
        let url = try #require(AppConstants.openAreaDeeplinkURL(
            areaId: "living_room",
            serverId: "server-1",
            dashboardPath: nil
        ))
        #expect(url.absoluteString.contains("navigate/config/areas/area/living_room"))
    }

    @Test func anAreaWithoutAnIdHasNoLink() {
        #expect(AppConstants.openAreaDeeplinkURL(areaId: "", serverId: "server-1", dashboardPath: "home") == nil)
    }

    private func answer(_ connection: HAMockConnection, request index: Int, with value: Any?) async {
        guard await waitForRequest(connection, index: index) else { return }
        connection.pendingRequests[index].completion(.success(.init(value: value)))
    }

    private func failRequest(_ connection: HAMockConnection, request index: Int) async {
        guard await waitForRequest(connection, index: index) else { return }
        connection.pendingRequests[index].completion(.failure(.internal(debugDescription: "config not found")))
    }

    /// The request is sent from a task of its own, so give it a moment to arrive rather than
    /// assuming it is already there.
    @discardableResult
    private func waitForRequest(_ connection: HAMockConnection, index: Int) async -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while connection.pendingRequests.count <= index, Date() < deadline {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        let arrived = connection.pendingRequests.count > index
        #expect(arrived)
        return arrived
    }
}
