@testable import HomeAssistant

import Foundation
import HAKit
@testable import Shared
import SharedTesting
import Testing
import WidgetKit

/// The common-controls widget's entries: the predicted entities it asks core for, the domains it
/// drops, the states it fetches, and the tiles it builds from them.
///
/// `.isolatedEnvironment`: servers, the API cache and the item info provider are installed per
/// test, and the stub connection answers on the test's own task and its child tasks.
@Suite(.isolatedEnvironment)
struct WidgetCommonlyUsedEntitiesTimelineTests {
    @available(iOS 17, *)
    private var provider: WidgetCommonlyUsedEntitiesTimelineProvider { .init() }

    /// Without a server, or with one that has no usable URL, or a prediction that fails, the widget
    /// has nothing to draw.
    @available(iOS 17, *)
    @Test func nothingIsPredictedWithoutAWorkingServer() async throws {
        Current.servers = FakeServerManager()
        let configuration = Self.configuration(serverId: "none")
        let withoutServer = await provider.fetchItems(family: .systemSmall, configuration: configuration)
        #expect(withoutServer.isEmpty)

        _ = install(serverId: "offline-\(UUID().uuidString)", offline: true) { _ in .failure(widgetStubUnexpected) }
        let offline = await provider.fetchItems(family: .systemSmall, configuration: configuration)
        #expect(offline.isEmpty)

        let failing = install(serverId: "failing-\(UUID().uuidString)") { _ in .failure(widgetStubUnexpected) }
        let failed = await provider.fetchItems(family: .systemSmall, configuration: configuration)
        #expect(failed.isEmpty)
        #expect(failing.sentCommands == ["usage_prediction/common_control"])
    }

    @available(iOS 17, *)
    @Test func theDomainPickerOffersEveryDomain() async throws {
        let query = WidgetDomainAppEntityQuery()
        let all = try await query.suggestedEntities()
        #expect(all.sections.flatMap(\.items).count == Domain.allCases.count)
        let matching = try await query.entities(matching: "light")
        #expect(matching.sections.flatMap(\.items).map(\.value.id).contains("light"))
        let byId = try await query.entities(for: ["light", "future_domain"])
        #expect(byId.map(\.id) == ["light", "future_domain"])
        #expect(byId.last?.name == "future_domain")
        #expect(!String(describing: byId[0].displayRepresentation.title).isEmpty)
        _ = WidgetCommonlyUsedEntitiesAppIntent.parameterSummary
    }

    // MARK: - Helpers

    @discardableResult
    private func install(
        serverId: String,
        offline: Bool = false,
        _ respond: @escaping WidgetStubConnection.Responder
    ) -> WidgetStubConnection {
        let servers = FakeServerManager()
        var info = ServerInfo.fake()
        if offline {
            info.connection.set(address: nil, for: .external)
        }
        let server = servers.add(identifier: .init(rawValue: serverId), serverInfo: info)
        Current.servers = servers
        Current.magicItemProvider = { WidgetPreviewMagicItemProvider() }
        let connection = WidgetStubConnection(respond: respond)
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        return connection
    }

    @available(iOS 17, *)
    private static func configuration(serverId: String) -> WidgetCommonlyUsedEntitiesAppIntent {
        let configuration = WidgetCommonlyUsedEntitiesAppIntent()
        configuration.server = .init(identifier: .init(rawValue: serverId))
        configuration.showStates = true
        configuration.showLastUpdateTime = true
        configuration.includedDomains = nil
        configuration.excludedDomains = nil
        return configuration
    }

    private final class EmptyInfoProvider: MagicItemProviderProtocol {
        func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
            completion([:])
        }

        func loadInformation() async -> [String: [HAAppEntity]] { [:] }

        func getInfo(for item: MagicItem) -> MagicItem.Info? { nil }

        func getAreaName(for item: MagicItem) -> String? { nil }
    }
}
