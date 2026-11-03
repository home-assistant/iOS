import Foundation
import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import Testing

/// Drives the private message handlers of `WatchCommunicatorService` through the dispatch closure
/// `setupMessages()` registers, the same entry point WatchConnectivity uses.
@MainActor
@Suite(.sharedState)
struct WatchCommunicatorMessageRoutingTests {
    // MARK: - Harness

    private final class Replies: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [HAWatchConnectivity.ImmediateMessage] = []

        func append(_ message: HAWatchConnectivity.ImmediateMessage) {
            lock.lock(); defer { lock.unlock() }
            storage.append(message)
        }

        var all: [HAWatchConnectivity.ImmediateMessage] {
            lock.lock(); defer { lock.unlock() }
            return storage
        }
    }

    /// Mirror pushes the code under test requested. Bound through `WatchMirrorPushCoordinator.scheduleOverride`
    /// for the whole test, so no debounced push is queued that would run after the harness restores `Current`.
    private final class MirrorPushes: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [WatchMirrorPushCoordinator.Reason] = []

        func record(_ reason: WatchMirrorPushCoordinator.Reason) {
            lock.lock(); defer { lock.unlock() }
            storage.append(reason)
        }

        var all: [WatchMirrorPushCoordinator.Reason] {
            lock.lock(); defer { lock.unlock() }
            return storage
        }
    }

    @MainActor
    private final class Harness {
        let service = WatchCommunicatorService()
        let servers = FakeServerManager()
        let mirrorPushes = MirrorPushes()
        let server: Server
        let database: DatabaseQueue
        private let observation: HAWatchConnectivity.Observation?
        private let handler: ((HAWatchConnectivity.InteractiveImmediateMessage) -> Void)?
        private let previousServers = Current.servers
        private let previousDatabase = Current.database
        private let previousProvider = Current.magicItemProvider
        private let previousCachedApis = Current.cachedApis
        private let previousPeerVersion = UserDefaults.standard.object(forKey: "watchMirrorPeerVersion")

        init(provider: MagicItemProviderProtocol = StubMagicItemProvider()) throws {
            Current.servers = servers
            self.server = servers.addFake()
            database = try DatabaseQueue()
            for table in DatabaseQueue.tables() {
                try table.createIfNeeded(database: database)
            }
            let database = database
            Current.database = { database }
            Current.magicItemProvider = { provider }

            let observable = Communicator.shared.interactiveImmediateMessage.observations
            let before = Set(observable.store.keys)
            service.setupMessages()
            let added = observable.store.first { !before.contains($0.key) }
            self.observation = added?.key
            self.handler = added?.value
        }

        func tearDown() {
            if let observation {
                Communicator.shared.interactiveImmediateMessage.observations.store[observation] = nil
            }
            Current.servers = previousServers
            Current.database = previousDatabase
            Current.magicItemProvider = previousProvider
            Current.cachedApis = previousCachedApis
            UserDefaults.standard.set(previousPeerVersion, forKey: "watchMirrorPeerVersion")
        }

        /// Delivers a message and waits (polling, bounded) for the first reply.
        func send(
            _ identifier: String,
            _ content: [String: Any] = [:],
            expectReply: Bool = true
        ) async throws -> HAWatchConnectivity.ImmediateMessage? {
            let handler = try #require(handler, "setupMessages() did not register a dispatch handler")
            let replies = Replies()
            handler(.init(identifier: identifier, content: content, reply: { replies.append($0) }))
            guard expectReply else { return replies.all.first }
            let deadline = Date().addingTimeInterval(10)
            while replies.all.isEmpty, Date() < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            return try #require(replies.all.first, "no reply to \(identifier)")
        }

        func send(_ message: InteractiveImmediateMessages, _ content: [String: Any] = [:]) async throws
            -> HAWatchConnectivity.ImmediateMessage {
            let reply = try await send(message.rawValue, content)
            return try #require(reply)
        }

        func useAPI(_ api: HomeAssistantAPI) {
            Current.cachedApis[server.identifier] = api
        }
    }

    private func withHarness(
        provider: MagicItemProviderProtocol = StubMagicItemProvider(),
        _ body: (Harness) async throws -> Void
    ) async throws {
        let harness = try Harness(provider: provider)
        defer { harness.tearDown() }
        let pushes = harness.mirrorPushes
        try await WatchMirrorPushCoordinator.$scheduleOverride.withValue({ pushes.record($0) }) {
            try await body(harness)
        }
    }

    // MARK: - Dispatch

    @Test func unknownIdentifierIsIgnored() async throws {
        try await withHarness { harness in
            let reply = try await harness.send("not-a-real-message", expectReply: false)
            #expect(reply == nil)
        }
    }

    @Test func pingAnswersWithPong() async throws {
        try await withHarness { harness in
            let reply = try await harness.send(.ping)
            #expect(reply.identifier == InteractiveImmediateResponses.pong.rawValue)
        }
    }

    @Test func serversConfigSyncRepliesWithServersAndNoCertificates() async throws {
        try await withHarness { harness in
            let reply = try await harness.send(.serversConfigSync)
            #expect(reply.identifier == InteractiveImmediateResponses.serversConfigSyncResponse.rawValue)
            #expect(reply.content["servers"] is Data)
            #expect(reply.content["clientCertificates"] == nil)
        }
    }

    @Test func clientCertImportRequestIsAcknowledged() async throws {
        try await withHarness { harness in
            let reply = try await harness.send(.clientCertImportRequest, ["serverId": "unknown-server"])
            #expect(reply.identifier == InteractiveImmediateResponses.clientCertImportRequestResponse.rawValue)
            #expect(reply.content["acknowledged"] as? Bool == true)
        }
    }

    @Test func httpRequestWithoutPayloadStillReplies() async throws {
        try await withHarness { harness in
            let reply = try await harness.send(.httpRequest)
            #expect(reply.identifier == InteractiveImmediateResponses.httpRequestResponse.rawValue)
        }
    }

    // MARK: - Vacuum areas

    @Test func vacuumAreasWithoutEntityRepliesEmpty() async throws {
        try await withHarness { harness in
            let reply = try await harness.send(.vacuumCleanableAreas, ["serverId": harness.server.identifier.rawValue])
            #expect(reply.identifier == InteractiveImmediateResponses.vacuumCleanableAreasResponse.rawValue)
            #expect((reply.content["areas"] as? [[String: String]])?.isEmpty == true)
        }
    }

    @Test func vacuumAreasResolvesMappedAreasAgainstTheDatabase() async throws {
        try await withHarness { harness in
            let serverId = harness.server.identifier.rawValue
            let api = HomeAssistantAPI(server: harness.server)
            let connection = HAMockConnection()
            api.connection = connection
            harness.useAPI(api)
            try await harness.database.write { db in
                try AppArea(
                    id: "\(serverId)-kitchen",
                    serverId: serverId,
                    areaId: "kitchen",
                    name: "Kitchen",
                    aliases: [],
                    picture: nil,
                    icon: nil,
                    sortOrder: nil,
                    entities: []
                ).insert(db)
            }

            let task = Task { @MainActor in
                try await harness.send(.vacuumCleanableAreas, ["entityId": "vacuum.robot", "serverId": serverId])
            }
            let deadline = Date().addingTimeInterval(10)
            while connection.pendingRequests.isEmpty, Date() < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            let request = try #require(connection.pendingRequests.first)
            request.completion(.success(.dictionary([
                "options": ["vacuum": ["area_mapping": ["kitchen": ["1"], "deleted_area": ["2"]]]],
            ])))
            let reply = try await task.value
            let areas = try #require(reply.content["areas"] as? [[String: String]])
            #expect(areas == [["id": "kitchen", "name": "Kitchen"]])
        }
    }

    @Test func vacuumAreasFailureRepliesEmpty() async throws {
        try await withHarness { harness in
            let serverId = harness.server.identifier.rawValue
            let api = HomeAssistantAPI(server: harness.server)
            let connection = HAMockConnection()
            api.connection = connection
            harness.useAPI(api)

            let task = Task { @MainActor in
                try await harness.send(.vacuumCleanableAreas, ["entityId": "vacuum.robot", "serverId": serverId])
            }
            let deadline = Date().addingTimeInterval(10)
            while connection.pendingRequests.isEmpty, Date() < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            let request = try #require(connection.pendingRequests.first)
            request.completion(.failure(.internal(debugDescription: "boom")))
            let reply = try await task.value
            #expect((reply.content["areas"] as? [[String: String]])?.isEmpty == true)
        }
    }

    // MARK: - Watch config

    @Test func watchConfigWithoutStoredConfigRepliesEmpty() async throws {
        try await withHarness { harness in
            let reply = try await harness.send(.watchConfig)
            #expect(reply.identifier == InteractiveImmediateResponses.emptyWatchConfigResponse.rawValue)
        }
    }

    @Test func watchConfigWithStoredConfigRepliesConfigAndItemInfo() async throws {
        try await withHarness { harness in
            let serverId = harness.server.identifier.rawValue
            var folder = MagicItem(id: "folder", serverId: serverId, type: .folder)
            folder.items = [MagicItem(id: "light.child", serverId: serverId, type: .entity)]
            let config = WatchConfig(
                id: WatchConfig.watchConfigId,
                items: [MagicItem(id: "script.one", serverId: serverId, type: .script), folder]
            )
            try await harness.database.write { db in try config.insert(db) }

            let reply = try await harness.send(.watchConfig)
            #expect(reply.identifier == InteractiveImmediateResponses.watchConfigResponse.rawValue)
            #expect(reply.content["config"] is Data)
            #expect((reply.content["magicItemsInfo"] as? [Data])?.count == 3)
        }
    }

    @Test func watchConfigUpdateWithoutConfigRevertsToStoredConfig() async throws {
        try await withHarness { harness in
            let reply = try await harness.send(.watchConfigUpdate, ["config": Data("nope".utf8)])
            #expect(reply.identifier == InteractiveImmediateResponses.emptyWatchConfigResponse.rawValue)
            #expect(harness.mirrorPushes.all.isEmpty)
        }
    }

    @Test func watchConfigUpdatePersistsTheEditedConfig() async throws {
        try await withHarness { harness in
            let edited = WatchConfig(id: "edited-on-watch", hideAreas: true)
            let encoded = try edited.encodeForWatch()
            let reply = try await harness.send(.watchConfigUpdate, ["config": encoded])
            #expect(reply.identifier == InteractiveImmediateResponses.watchConfigResponse.rawValue)

            let stored = try await harness.database.read { db in try WatchConfig.fetchAll(db) }
            #expect(stored.count == 1)
            #expect(stored.first?.id == WatchConfig.watchConfigId)
            #expect(stored.first?.hideAreas == true)
            #expect(harness.mirrorPushes.all == [.watchConfigChanged])
        }
    }

    @Test func watchConfigAvailableItemsRepliesWithEncodedGroups() async throws {
        try await withHarness { harness in
            let reply = try await harness.send(.watchConfigAvailableItems)
            #expect(reply.identifier == InteractiveImmediateResponses.watchConfigAvailableItemsResponse.rawValue)
            #expect(reply.content["availableItems"] is Data)
        }
    }

    // MARK: - Database mirror

    @Test func databaseMirrorSyncServesEveryChunkThenForgetsTheTransfer() async throws {
        try await withHarness { harness in
            let start = try await harness.send(.watchDatabaseMirror, [
                WatchDatabaseMirror.versionKey: WatchDatabaseMirror.fullReferenceVersion,
                WatchDatabaseMirror.digestsKey: ["unknown": "digest"],
            ])
            #expect(start.identifier == InteractiveImmediateResponses.watchDatabaseMirrorResponse.rawValue)
            let transferId = try #require(start.content["transferId"] as? String)
            let totalChunks = try #require(start.content["totalChunks"] as? Int)
            #expect(totalChunks >= 1)
            #expect(start.content[WatchDatabaseMirror.compressedKey] as? Bool == true)

            for index in 0 ..< totalChunks {
                let chunk = try await harness.send(
                    .watchDatabaseMirrorChunk,
                    ["transferId": transferId, "index": index]
                )
                #expect(chunk.content["index"] as? Int == index)
                #expect(chunk.content["chunkData"] is Data)
            }

            let again = try await harness.send(.watchDatabaseMirrorChunk, ["transferId": transferId, "index": 0])
            #expect(again.content["error"] as? Bool == true)
        }
    }

    @Test func databaseMirrorLegacySyncIsUncompressed() async throws {
        try await withHarness { harness in
            _ = try await harness.send(.watchDatabaseMirror)
            let start = try await harness.send(.watchDatabaseMirror)
            #expect(start.content["transferId"] is String)
            #expect(start.content[WatchDatabaseMirror.compressedKey] == nil)
        }
    }

    @Test func databaseMirrorChunkWithBadRequestRepliesError() async throws {
        try await withHarness { harness in
            let reply = try await harness.send(.watchDatabaseMirrorChunk, ["transferId": "missing", "index": 0])
            #expect(reply.identifier == InteractiveImmediateResponses.watchDatabaseMirrorChunkResponse.rawValue)
            #expect(reply.content["error"] as? Bool == true)
        }
    }

    // MARK: - Magic item presses

    private func press(
        _ harness: Harness,
        type: String?,
        id: String? = "script.one",
        serverId: String? = nil,
        triggeredAt: TimeInterval? = nil
    ) async throws -> [String: Any] {
        var content: [String: Any] = [:]
        content["itemType"] = type
        content["itemId"] = id
        content["serverId"] = serverId ?? harness.server.identifier.rawValue
        content["triggeredAt"] = triggeredAt
        return try await harness.send(.magicItemPressed, content).content
    }

    private func failureCode(_ content: [String: Any]) -> MagicItemExecutionFailureCode? {
        #expect(content["fired"] as? Bool == false)
        return (content["errorCode"] as? String).flatMap(MagicItemExecutionFailureCode.init(rawValue:))
    }

    private func pressCode(
        _ harness: Harness,
        type: String?,
        id: String? = "script.one",
        serverId: String? = nil,
        triggeredAt: TimeInterval? = nil
    ) async throws -> MagicItemExecutionFailureCode? {
        let content = try await press(harness, type: type, id: id, serverId: serverId, triggeredAt: triggeredAt)
        return failureCode(content)
    }

    @Test func magicItemStalePressIsRejected() async throws {
        try await withHarness { harness in
            let stale = Current.date().timeIntervalSince1970 - 120
            let code = try await pressCode(harness, type: "script", triggeredAt: stale)
            #expect(code == .staleRequest)
        }
    }

    @Test func magicItemPressFromTheFutureStillRuns() async throws {
        try await withHarness { harness in
            let future = Current.date().timeIntervalSince1970 + 60
            let code = try await pressCode(harness, type: "folder", triggeredAt: future)
            #expect(code == .notExecutable)
        }
    }

    @Test func magicItemPressRejectsInvalidAndNonExecutableItems() async throws {
        try await withHarness { harness in
            let missingType = try await pressCode(harness, type: nil)
            #expect(missingType == .invalidItem)
            let bogusType = try await pressCode(harness, type: "bogus")
            #expect(bogusType == .invalidItem)
            let folder = try await pressCode(harness, type: "folder")
            #expect(folder == .notExecutable)
            let unknownServer = try await pressCode(harness, type: "script", serverId: "nope")
            #expect(unknownServer == .serverNotFound)
            for type in ["area", "assistPipeline", "assistPrompt", "complication", "unsupported"] {
                let code = try await pressCode(harness, type: type)
                #expect(code == .notExecutable, "\(type)")
            }
            let sensor = try await pressCode(harness, type: "entity", id: "sensor.temperature")
            #expect(sensor == .notExecutable)
        }
    }

    @Test func magicItemPressCallsTheMatchingService() async throws {
        try await withHarness { harness in
            let api = FakeCallServiceAPI(server: harness.server)
            harness.useAPI(api)

            let script = try await press(harness, type: "script", id: "script.morning")
            let scene = try await press(harness, type: "scene", id: "scene.movie")
            let light = try await press(harness, type: "entity", id: "light.kitchen")
            #expect(script["fired"] as? Bool == true)
            #expect(scene["fired"] as? Bool == true)
            #expect(light["fired"] as? Bool == true)

            #expect(api.calls.map(\.domain) == ["script", "scene", "light"])
            #expect(api.calls.map(\.service) == ["morning", "turn_on", "toggle"])
            #expect(api.calls.dropFirst().first?.data["entity_id"] as? String == "scene.movie")
        }
    }

    @Test func magicItemPressReportsServiceFailure() async throws {
        try await withHarness { harness in
            let api = FakeCallServiceAPI(server: harness.server)
            api.failure = URLError(.timedOut)
            harness.useAPI(api)

            let content = try await press(harness, type: "script", id: "script.morning")
            #expect(failureCode(content) == .serviceCallFailed)
            #expect(content["error"] as? String != nil)
        }
    }

    // MARK: - Assist pipelines

    @Test func assistPipelinesForUnknownServerRepliesError() async throws {
        try await withHarness { harness in
            let reply = try await harness.send(.assistPipelinesFetch, ["serverId": "unknown"])
            #expect(reply.identifier == InteractiveImmediateResponses.assistPipelinesFetchResponse.rawValue)
            #expect(reply.content["error"] as? Bool == true)
        }
    }

    @Test func assistPipelinesRepliesWithFetchedPipelines() async throws {
        try await withHarness { harness in
            let assist = MockAssistService()
            assist.pipelineResponse = PipelineResponse(
                preferredPipeline: "voice",
                pipelines: [Pipeline(id: "voice", name: "Voice", sttEngine: nil, ttsEngine: nil)]
            )
            harness.service.makeAssistService = { _ in assist }

            let reply = try await harness.send(.assistPipelinesFetch)
            #expect(reply.content["preferredPipeline"] as? String == "voice")
            #expect((reply.content["pipelines"] as? [[String: String]])?.first?["name"] == "Voice")
        }
    }

    @Test func assistPipelinesWithoutResponseRepliesErrorOrCache() async throws {
        try await withHarness { harness in
            let assist = MockAssistService()
            harness.service.makeAssistService = { _ in assist }

            let reply = try await harness.send(.assistPipelinesFetch, ["serverId": harness.server.identifier.rawValue])
            #expect(reply.identifier == InteractiveImmediateResponses.assistPipelinesFetchResponse.rawValue)
            #expect(reply.content["error"] as? Bool == true || reply.content["pipelines"] != nil)
        }
    }

    // MARK: - Server observer

    @Test func serversDidChangeSyncsContextAndSchedulesAMirrorPush() throws {
        let harness = try Harness()
        defer { harness.tearDown() }
        let pushes = harness.mirrorPushes
        var contextSyncs = 0
        harness.service.syncWatchContext = { contextSyncs += 1 }
        WatchMirrorPushCoordinator.$scheduleOverride.withValue({ pushes.record($0) }) {
            harness.service.serversDidChange(harness.servers)
        }
        #expect(harness.servers.all.count == 1)
        #expect(contextSyncs == 1)
        #expect(pushes.all == [.serversChanged])
    }
}

private final class StubMagicItemProvider: MagicItemProviderProtocol {
    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        .init(id: item.serverUniqueId, name: item.id, iconName: "mdi:script", contextSubtitle: nil)
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}

private final class FakeCallServiceAPI: HomeAssistantAPI {
    struct Call {
        let domain: String
        let service: String
        let data: [String: Any]
    }

    var failure: Error?
    private(set) var calls: [Call] = []

    override func CallService(
        domain: String,
        service: String,
        serviceData: [String: Any],
        triggerSource: AppTriggerSource,
        shouldLog: Bool = true
    ) -> Promise<Void> {
        calls.append(.init(domain: domain, service: service, data: serviceData))
        if let failure {
            return Promise(error: failure)
        }
        return .value(())
    }
}
