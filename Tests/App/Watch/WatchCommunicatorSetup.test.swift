import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// `WatchCommunicatorService.setup()` registers observers on the shared WatchConnectivity manager.
/// The test runs the registered handlers directly with synthetic events, then unregisters them again.
/// Everything the service would send to the watch goes to the injected `Outgoing` fake instead, so a
/// paired watch never receives this test's configs or context.
@MainActor
@Suite(.sharedState)
struct WatchCommunicatorSetupTests {
    private struct Registration<T> {
        let observable: HAWatchConnectivity.Observable<T>
        let before: Set<HAWatchConnectivity.Observation>

        init(_ observable: HAWatchConnectivity.Observable<T>) {
            self.observable = observable
            self.before = Set(observable.store.keys)
        }

        var added: [(HAWatchConnectivity.Observation, (T) -> Void)] {
            observable.store.filter { !before.contains($0.key) }.map { ($0.key, $0.value) }
        }

        func fire(_ value: T) {
            added.forEach { $0.1(value) }
        }

        func remove() {
            for (key, _) in added {
                observable.store[key] = nil
            }
        }
    }

    private final class StubProvider: MagicItemProviderProtocol {
        func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) { completion([:]) }
        func loadInformation() async -> [String: [HAAppEntity]] { [:] }
        func getInfo(for item: MagicItem) -> MagicItem.Info? {
            .init(id: item.serverUniqueId, name: item.id, iconName: "mdi:script", contextSubtitle: nil)
        }

        func getAreaName(for item: MagicItem) -> String? { nil }
    }

    /// Captures what the service hands to WatchConnectivity.
    private final class Outgoing {
        var guaranteed: [HAWatchConnectivity.GuaranteedMessage] = []
        var contextSyncs = 0
    }

    @Test func registeredHandlersReactToWatchEvents() async throws {
        let previousServers = Current.servers
        let previousDatabase = Current.database
        let previousProvider = Current.magicItemProvider
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        Current.servers = FakeServerManager()
        Current.database = { database }
        Current.magicItemProvider = { StubProvider() }

        let communicator = Communicator.shared
        let state = Registration(communicator.state)
        let watchState = Registration(communicator.watchState)
        let reachability = Registration(communicator.reachability)
        let interactive = Registration(communicator.interactiveImmediateMessage)
        let guaranteed = Registration(communicator.guaranteedMessage)
        let blob = Registration(communicator.blob)
        let context = Registration(communicator.context)
        defer {
            state.remove()
            watchState.remove()
            reachability.remove()
            interactive.remove()
            guaranteed.remove()
            blob.remove()
            context.remove()
            Current.servers = previousServers
            Current.database = previousDatabase
            Current.magicItemProvider = previousProvider
        }

        let outgoing = Outgoing()
        let service = WatchCommunicatorService()
        service.sendGuaranteed = { outgoing.guaranteed.append($0) }
        service.syncWatchContext = { outgoing.contextSyncs += 1 }
        service.setup()
        #expect(guaranteed.added.count == 1)
        #expect(blob.added.count == 1)
        #expect(context.added.count == 1)

        // Activation and pairing changes push the context; reachability only logs.
        state.fire(.activated)
        watchState.fire(.notPaired)
        reachability.fire(.notReachable)
        #expect(outgoing.contextSyncs == 2)

        // Guaranteed watch config requests are answered whether or not a config is stored; unknown
        // identifiers are ignored.
        guaranteed.fire(.init(identifier: "notAKnownMessage"))
        #expect(outgoing.guaranteed.isEmpty)
        guaranteed.fire(.init(identifier: InteractiveImmediateMessages.watchConfig.rawValue))
        #expect(outgoing.guaranteed.map(\.identifier) == [
            InteractiveImmediateResponses.emptyWatchConfigResponse.rawValue,
        ])
        try await database.write { db in
            try WatchConfig(
                id: WatchConfig.watchConfigId,
                items: [MagicItem(id: "script.a", serverId: "s", type: .script)]
            )
            .insert(db)
        }
        guaranteed.fire(.init(identifier: InteractiveImmediateMessages.watchConfig.rawValue))
        // The stub provider answers synchronously, so the reply is already sent.
        #expect(outgoing.guaranteed.map(\.identifier) == [
            InteractiveImmediateResponses.emptyWatchConfigResponse.rawValue,
            InteractiveImmediateResponses.watchConfigResponse.rawValue,
        ])
        let configReply = try #require(outgoing.guaranteed.last)
        #expect(configReply.content["config"] is Data)
        #expect((configReply.content["magicItemsInfo"] as? [Data])?.count == 1)

        // Only the diagnostics archive is saved; other blobs are ignored.
        blob.fire(.init(identifier: "something-else", content: Data([1])))
        let fileName = "a6-setup-test.watch-logs.zip"
        blob.fire(.init(
            identifier: WatchDiagnosticsTransfer.blobIdentifier,
            content: Data([1, 2, 3]),
            metadata: ["fileName": fileName]
        ))
        let saved = AppConstants.LogsDirectory.appendingPathComponent(fileName)
        #expect(FileManager.default.fileExists(atPath: saved.path))
        try? FileManager.default.removeItem(at: saved)

        context.fire(.init(content: [WatchContext.watchModel.rawValue: "Watch7,1"]))
        context.fire(.init(content: [:]))
    }
}
