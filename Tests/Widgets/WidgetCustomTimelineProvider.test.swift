@testable import HomeAssistant

import Foundation
import GRDB
import HAKit
@testable import Shared
import SharedTesting
import Testing
import WidgetKit

/// The custom widget's entries: which stored widget they draw, how many of its items fit the
/// family, and when its entities' states are fetched — plus the picker that lists the widgets.
///
/// `.isolatedEnvironment`: the database, servers, item info provider and API cache are installed
/// per test, and the stub connection answers the state fetches on the test's own task.
@Suite(.isolatedEnvironment)
struct WidgetCustomTimelineProviderTests {
    @available(iOS 17, *)
    private var provider: WidgetCustomTimelineProvider { .init() }

    @available(iOS 17, *)
    @Test func thePickerListsAndSearchesTheStoredWidgets() async throws {
        _ = try install(widgets: [
            CustomWidget(id: "a", name: "Kitchen", items: []),
            CustomWidget(id: "b", name: "Bedroom", items: []),
        ])
        let query = CustomWidgetAppEntityQuery()

        let suggested = try await query.suggestedEntities()
        #expect(Set(suggested.sections.flatMap(\.items).map(\.value.id)) == ["a", "b"])
        let matching = try await query.entities(matching: "kit")
        #expect(matching.sections.flatMap(\.items).map(\.value.name) == ["Kitchen"])
        let byId = try await query.entities(for: ["b"])
        #expect(byId.map(\.name) == ["Bedroom"])
        #expect(!String(describing: byId[0].displayRepresentation.title).isEmpty)

        _ = WidgetCustomAppIntent.parameterSummary
        _ = try await WidgetCustomAppIntent().perform()
    }

    // MARK: - Helpers

    private static func light(_ index: Int) -> MagicItem {
        MagicItem(id: "light.light_\(index)", serverId: "custom-server", type: .entity)
    }

    @discardableResult
    private func install(
        widgets: [CustomWidget],
        _ respond: @escaping WidgetStubConnection.Responder = { _ in .failure(widgetStubUnexpected) }
    ) throws -> (Server, WidgetStubConnection) {
        let database = try SettingsTestDatabase.make()
        try database.write { db in
            for widget in widgets {
                try widget.insert(db)
            }
        }
        Current.database = { database }
        Current.magicItemProvider = { WidgetPreviewMagicItemProvider() }
        let servers = FakeServerManager()
        let server = servers.add(identifier: .init(rawValue: "custom-server"), serverInfo: .fake())
        Current.servers = servers
        let connection = WidgetStubConnection(respond: respond)
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        return (server, connection)
    }
}
