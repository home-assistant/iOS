@testable import HomeAssistant

import Foundation
import HAKit
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// How the widgets' state fetcher decides between its cache and the server, and what it keeps when
/// part of a batch fails.
///
/// `.isolatedEnvironment`: the fetches run in child tasks of the test, which inherit its
/// environment, and the stub connection answers on them.
@Suite(.isolatedEnvironment)
struct WidgetEntityStateProviderTests {
    @available(iOS 17, *)
    @Test func hiddenOrSkippedStatesAreNeverFetched() async {
        let cacheURL = Self.temporaryURL()
        let hidden = await Self.provider(cacheURL: cacheURL).states(showStates: false, items: [Self.light])
        #expect(hidden.isEmpty)

        let skipped = await Self.provider(cacheURL: cacheURL, shouldFetch: false, skipMessage: "skip")
            .states(showStates: true, items: [Self.light])
        #expect(skipped.isEmpty)
        let skippedSilently = await Self.provider(cacheURL: cacheURL, shouldFetch: false, skipMessage: nil)
            .states(showStates: true, items: [Self.light])
        #expect(skippedSilently.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: cacheURL.path))
    }

    @available(iOS 17, *)
    @Test func aFreshCacheIsServedWithoutAskingTheServer() async throws {
        let cacheURL = Self.temporaryURL()
        defer { try? FileManager.default.removeItem(at: cacheURL) }
        let connection = install { _ in .failure(widgetStubUnexpected) }
        try Self.writeCache([Self.light: Self.state("Cached")], createdAt: Date(), to: cacheURL)

        let states = await Self.provider(cacheURL: cacheURL, validity: 600).states(
            showStates: true,
            items: [Self.light]
        )
        #expect(states[Self.light]?.value == "Cached")
        #expect(connection.sent.isEmpty)
    }

    /// A stale cache is refreshed; an item whose fetch fails keeps its cached state, items the
    /// filter rejects or that name no known server are left out, and the result is cached.
    @available(iOS 17, *)
    @Test func aStaleCacheIsRefreshedKeepingWhatFailed() async throws {
        let cacheURL = Self.temporaryURL()
        defer { try? FileManager.default.removeItem(at: cacheURL) }
        let connection = install { request in
            switch request.type.command {
            case "states/light.kitchen":
                .success(HAData(value: [
                    "state": "on",
                    "attributes": ["device_class": "light", "rgb_color": [255, 0, 0], "unit_of_measurement": "%"],
                ]))
            default: .failure(widgetStubUnexpected)
            }
        }
        let failing = MagicItem(id: "sensor.failing", serverId: "state-server", type: .entity)
        let unknownServer = MagicItem(id: "light.elsewhere", serverId: "gone", type: .entity)
        let noDomain = MagicItem(id: "nodomain", serverId: "state-server", type: .entity)
        let filtered = MagicItem(id: "script.morning", serverId: "state-server", type: .script)
        try Self.writeCache(
            [failing: Self.state("Old")],
            createdAt: Date(timeIntervalSinceNow: -3600),
            to: cacheURL
        )

        let states = await Self.provider(cacheURL: cacheURL).states(
            showStates: true,
            items: [Self.light, failing, unknownServer, noDomain, filtered]
        )

        #expect(states[Self.light]?.value == "On|%")
        #expect(states[Self.light]?.rawState == "on")
        #expect(states[failing]?.value == "Old")
        #expect(states[unknownServer] == nil)
        #expect(states[noDomain] == nil)
        #expect(states[filtered] == nil)
        #expect(!connection.sentCommands.contains("states/script.morning"))

        let cached = try JSONDecoder().decode(WidgetEntitiesStateCache.self, from: Data(contentsOf: cacheURL))
        #expect(cached.states.count == 2)
        _ = states[Self.light]?.iconColor(domain: .light)
        _ = states[Self.light]?.iconColor(domain: nil, customColor: .red)
    }

    /// A cache file that cannot be decoded is ignored, and a cache that cannot be written is only
    /// logged: either way the fetched states are returned.
    @available(iOS 17, *)
    @Test func anUnreadableOrUnwritableCacheStillReturnsTheStates() async throws {
        let corruptURL = Self.temporaryURL()
        defer { try? FileManager.default.removeItem(at: corruptURL) }
        try Data("not json".utf8).write(to: corruptURL)
        _ = install { _ in .success(HAData(value: ["state": "off", "attributes": [String: Any]()])) }

        let fromCorrupt = await Self.provider(cacheURL: corruptURL).states(showStates: true, items: [Self.light])
        #expect(fromCorrupt[Self.light]?.rawState == "off")

        let unwritable = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("missing", isDirectory: true)
            .appendingPathComponent("cache.json")
        let fromUnwritable = await Self.provider(cacheURL: unwritable).states(showStates: true, items: [Self.light])
        #expect(fromUnwritable[Self.light]?.rawState == "off")
        #expect(!FileManager.default.fileExists(atPath: unwritable.path))

        let none = await Self.provider(cacheURL: Self.temporaryURL()).states(showStates: true, items: [])
        #expect(none.isEmpty)
    }

    // MARK: - Helpers

    private static let light = MagicItem(id: "light.kitchen", serverId: "state-server", type: .entity)

    @available(iOS 17, *)
    private static func provider(
        cacheURL: URL,
        validity: TimeInterval = 1,
        shouldFetch: Bool = true,
        skipMessage: String? = nil
    ) -> WidgetEntityStateProvider {
        WidgetEntityStateProvider(
            logPrefix: "Test",
            cacheValiditySeconds: validity,
            cacheURL: { cacheURL },
            shouldFetchStates: { shouldFetch },
            skipFetchLogMessage: skipMessage,
            itemFilter: { $0.type != .script },
            stateValueFormatter: { state, _, _ in "\(state.value)|\(state.unitOfMeasurement ?? "")" }
        )
    }

    private static func state(_ value: String) -> WidgetEntityState {
        WidgetEntityState(
            value: value,
            domainState: nil,
            rawState: value.lowercased(),
            deviceClass: nil,
            liveColorHex: nil,
            groupMemberDomain: nil
        )
    }

    private static func writeCache(_ states: [MagicItem: WidgetEntityState], createdAt: Date, to url: URL) throws {
        let data = try JSONEncoder().encode(WidgetEntitiesStateCache(cacheCreatedDate: createdAt, states: states))
        try data.write(to: url)
    }

    private static func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("widget-states-\(UUID().uuidString).json")
    }

    private func install(_ respond: @escaping WidgetStubConnection.Responder) -> WidgetStubConnection {
        let servers = FakeServerManager()
        let server = servers.add(identifier: .init(rawValue: "state-server"), serverInfo: .fake())
        Current.servers = servers
        let connection = WidgetStubConnection(respond: respond)
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        return connection
    }
}
