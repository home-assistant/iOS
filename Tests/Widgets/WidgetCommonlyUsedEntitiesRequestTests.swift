import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import Testing
import WidgetKit

/// Covers what the commonly-used-entities widget asks core for: a `limit` sized to the widget, but
/// only from the core version that accepts one.
@Suite(.serialized)
struct WidgetCommonlyUsedEntitiesRequestTests {
    private static let supportedVersions = [
        Version(major: 2026, minor: 10, patch: 0, prerelease: "b0"),
        Version(major: 2026, minor: 10, patch: 0, prerelease: "b3"),
        Version(major: 2026, minor: 10, patch: 0),
        Version(major: 2026, minor: 11, patch: 1),
    ]

    private static let families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]

    private static let predictedEntities = [
        "light.kitchen",
        "switch.desk_lamp",
        "cover.garage_door",
        "fan.bedroom",
        "scene.movie_night",
        "lock.front_door",
    ]

    @Test(arguments: [
        Version(major: 2026, minor: 9, patch: 0),
        Version(major: 2026, minor: 9, patch: 3),
    ])
    func olderCoreGetsTheDefaultRequest(version: Version) {
        guard #available(iOS 17, *) else { return }
        let request = WidgetCommonlyUsedEntitiesTimelineProvider.usagePredictionRequest(
            server: .fake(update: { info in info.version = version }),
            family: .systemLarge,
            domainFilter: WidgetDomainFilter()
        )
        #expect(request.request.type == .webSocket("usage_prediction/common_control"))
        #expect(request.request.data.isEmpty)
    }

    /// Every 2026.10 beta counts, not just the release.
    @Test(arguments: supportedVersions)
    func supportedCoreGetsALimit(version: Version) {
        guard #available(iOS 17, *) else { return }
        let request = WidgetCommonlyUsedEntitiesTimelineProvider.usagePredictionRequest(
            server: .fake(update: { info in info.version = version }),
            family: .systemLarge,
            domainFilter: WidgetDomainFilter()
        )
        #expect(request.request.data["limit"] as? Int == WidgetFamilySizes.size(for: .systemLarge, capacity: .tile))
    }

    @Test(arguments: families)
    func limitMatchesTheTilesTheFamilyShows(family: WidgetFamily) {
        guard #available(iOS 17, *) else { return }
        let request = WidgetCommonlyUsedEntitiesTimelineProvider.usagePredictionRequest(
            server: .fake(update: { info in info.version = .usagePredictionCommonControlLimit }),
            family: family,
            domainFilter: WidgetDomainFilter()
        )
        #expect(request.request.data["limit"] as? Int == WidgetFamilySizes.size(for: family, capacity: .tile))
    }

    /// The domain filter runs after the prediction arrives, so asking for only the family's size
    /// would leave tiles empty once it drops some.
    @Test(arguments: families)
    func domainFilterAsksForMore(family: WidgetFamily) {
        guard #available(iOS 17, *) else { return }
        let request = WidgetCommonlyUsedEntitiesTimelineProvider.usagePredictionRequest(
            server: .fake(update: { info in info.version = .usagePredictionCommonControlLimit }),
            family: family,
            domainFilter: WidgetDomainFilter(includedDomains: [Domain.light.rawValue])
        )
        #expect(
            request.request.data["limit"] as? Int == WidgetCommonlyUsedEntitiesTimelineProvider
                .filteredPredictionLimit
        )
    }

    /// The widget sends the family-sized request and draws what core predicts, up to the tiles it shows.
    @MainActor
    @Test func fetchingSendsTheLimitAndDrawsThePrediction() async throws {
        guard #available(iOS 17, *) else { return }
        try await withConnectedServer(version: .usagePredictionCommonControlLimit) { server, connection in
            let configuration = WidgetCommonlyUsedEntitiesAppIntent()
            configuration.server = IntentServerAppEntity(from: server)
            let tiles = WidgetFamilySizes.size(for: .systemMedium, capacity: .tile)

            let fetch = Task {
                await WidgetCommonlyUsedEntitiesTimelineProvider().fetchItems(
                    family: .systemMedium,
                    configuration: configuration
                )
            }
            let request = try await firstPendingRequest(on: connection)
            #expect(request.request.data["limit"] as? Int == tiles)
            request.completion(.success(.dictionary(["entities": Self.predictedEntities])))

            let items = await fetch.value
            #expect(items.map(\.id) == Array(Self.predictedEntities.prefix(tiles)))
            #expect(items.allSatisfy { $0.serverId == server.identifier.rawValue })
        }
    }

    /// Points `Current` at one fake server on `version`, whose API talks to a mock connection.
    @MainActor
    private func withConnectedServer(
        version: Version,
        _ body: (Server, HAMockConnection) async throws -> Void
    ) async throws {
        let previousServers = Current.servers
        var info = ServerInfo.fake()
        info.version = version
        let manager = FakeServerManager()
        let server = manager.add(identifier: .init(rawValue: "common-controls"), serverInfo: info)
        let api = HomeAssistantAPI(server: server)
        let connection = HAMockConnection()
        api.connection = connection
        Current.servers = manager
        Current.cachedApis[server.identifier] = api
        defer {
            Current.servers = previousServers
            Current.cachedApis[server.identifier] = nil
        }
        try await body(server, connection)
    }

    /// The widget sends from its own task, so give it a moment to reach the connection.
    @MainActor
    private func firstPendingRequest(on connection: HAMockConnection) async throws -> HAMockConnection.PendingRequest {
        for _ in 0 ..< 500 {
            if let request = connection.pendingRequests.first {
                return request
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("The widget never sent a request")
        throw CancellationError()
    }
}
