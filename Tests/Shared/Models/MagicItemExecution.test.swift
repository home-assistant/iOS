import Foundation
import GRDB
import HAKit
import PromiseKit
@testable import Shared
import SharedTesting
import Testing

/// Running a magic item from a tile or shortcut — scripts and scenes through the webhook, entities
/// through the WebSocket, a lock by its current state — plus the helpers that describe an item.
///
/// `.isolatedEnvironment`: the server, API cache and webhook manager are read on the test's task
/// before the request goes out; the outcome is polled for, since an entity's arrives on the main
/// queue.
@Suite(.isolatedEnvironment)
struct MagicItemExecutionTests {
    @Test func scriptsAndScenesRunThroughTheWebhook() async throws {
        let (server, webhooks, _) = install()
        let script = MagicItem(id: "script.morning", serverId: server.identifier.rawValue, type: .script)
        let scriptResult = try await run(script, on: server)
        #expect(scriptResult.success)

        let scene = MagicItem(id: "scene.movie", serverId: server.identifier.rawValue, type: .scene)
        let sceneResult = try await run(scene, on: server)
        #expect(sceneResult.success)
        #expect(webhooks.services == ["script.morning", "scene.turn_on"])

        webhooks.fails = true
        let failed = try await run(scene, on: server)
        #expect(!failed.success)
        #expect(failed.error != nil)
    }

    @Test func entitiesRunTheirDomainsMainAction() async throws {
        let (server, _, connection) = install()
        let button = MagicItem(id: "button.doorbell", serverId: server.identifier.rawValue, type: .entity)
        let pressed = try await run(button, on: server)
        #expect(pressed.success)

        let lock = MagicItem(id: "lock.front", serverId: server.identifier.rawValue, type: .entity)
        _ = try await run(lock, on: server, state: "unlocked")
        _ = try await run(lock, on: server, state: "locked")
        _ = try await run(lock, on: server, state: "jammed")
        _ = try await run(lock, on: server, state: "not-a-state")

        let services = connection.sentServices
        #expect(services == ["button.press", "lock.lock", "lock.unlock"])
    }

    @Test func itemsWithNothingToRunSucceedAndUnknownOnesFail() async throws {
        let (server, _, connection) = install()
        for type: MagicItem.ItemType in [.folder, .area, .assistPipeline, .unsupported] {
            let result = try await run(MagicItem(id: "x", serverId: "s", type: type), on: server)
            #expect(result.success)
        }
        let unknown = try await run(MagicItem(id: "nodomain", serverId: "s", type: .entity), on: server)
        #expect(!unknown.success)
        #expect(connection.sentServices.isEmpty)

        let offline = Server.fake { info in info.connection.set(address: nil, for: .external) }
        let noAPI = try await run(MagicItem(id: "script.a", serverId: "s", type: .script), on: offline)
        #expect(!noAPI.success)
    }

    // MARK: - Describing an item

    @Test func contentComparesEveryField() {
        let item = MagicItem(id: "light.a", serverId: "s", type: .entity, displayText: "A")
        var edited = item
        edited.displayText = "B"
        #expect(item.contentEquals(item))
        #expect(!item.contentEquals(edited))
        #expect(item.contentHash != edited.contentHash)
        let folder = MagicItem(id: "f", serverId: "s", type: .folder, items: [item])
        #expect(folder.contentHash == folder.contentHash)
    }

    @Test func iconsFallBackPerType() {
        let info = MagicItem.Info(id: "x", name: "X", iconName: "mdi:not-an-icon")
        for type: MagicItem.ItemType in [
            .scene, .script, .entity, .folder, .area, .complication, .assistPipeline, .assistPrompt, .unsupported,
        ] {
            _ = MagicItem(id: "x", serverId: "s", type: type, customization: nil).icon(info: info)
        }
        let customized = MagicItem(id: "x", serverId: "s", type: .entity, customization: .init(icon: "lightbulb"))
        _ = customized.icon(info: info)
    }

    @Test func actionsAreNamedForTheirDomain() {
        for action in ItemAction.allCases {
            #expect(!action.name.isEmpty)
            #expect(!action.id.isEmpty)
            #expect(!action.name(for: nil).isEmpty)
            #expect(!action.name(for: .lock).isEmpty)
        }
        #expect(ItemAction.turnOn.name(for: .sensor) == ItemAction.turnOn.name)
        #expect(ItemAction.turnOff.name(for: nil) == ItemAction.turnOff.name)
        #expect(!ItemAction.defaultName(resolvingTo: "Toggle").isEmpty)
    }

    // MARK: - Helpers

    private func install() -> (Server, RecordingWebhooks, RespondingHAConnection) {
        let servers = FakeServerManager()
        let server = servers.add(identifier: .init(rawValue: "magic-server"), serverInfo: .fake())
        Current.servers = servers
        let connection = RespondingHAConnection { _ in .success(.empty) }
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        let webhooks = RecordingWebhooks()
        Current.webhooks = webhooks
        return (server, webhooks, connection)
    }

    private struct Outcome {
        let success: Bool
        let error: Error?
    }

    private struct NeverCompleted: Error {}

    /// Runs `item` and waits, at most ten seconds, for its completion.
    private func run(_ item: MagicItem, on server: Server, state: String = "") async throws -> Outcome {
        let box = OutcomeBox()
        item.execute(on: server, source: .Widget, currentItemState: state) { success, error in
            box.set(Outcome(success: success, error: error))
        }
        let deadline = Date().addingTimeInterval(10)
        while box.value == nil, Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        guard let outcome = box.value else { throw NeverCompleted() }
        return outcome
    }

    private final class OutcomeBox: @unchecked Sendable {
        private let lock = NSLock()
        private var outcome: Outcome?

        var value: Outcome? {
            lock.lock()
            defer { lock.unlock() }
            return outcome
        }

        func set(_ outcome: Outcome) {
            lock.lock()
            self.outcome = outcome
            lock.unlock()
        }
    }

    private final class RecordingWebhooks: WebhookManager {
        private let lock = NSLock()
        private var sent: [String] = []
        private var shouldFail = false

        var fails: Bool {
            get {
                lock.lock()
                defer { lock.unlock() }
                return shouldFail
            }
            set {
                lock.lock()
                shouldFail = newValue
                lock.unlock()
            }
        }

        var services: [String] {
            lock.lock()
            defer { lock.unlock() }
            return sent
        }

        override func send(
            identifier: WebhookResponseIdentifier = .unhandled,
            server: Server,
            request: WebhookRequest
        ) -> Promise<Void> {
            let data = request.data as? [String: Any]
            lock.lock()
            sent.append("\(data?["domain"] as? String ?? "").\(data?["service"] as? String ?? "")")
            let fail = shouldFail
            lock.unlock()
            return fail ? .init(error: ServiceFailed()) : .value(())
        }

        struct ServiceFailed: Error {}
    }
}

private extension RespondingHAConnection {
    /// The `domain.service` of every call sent so far.
    var sentServices: [String] {
        sentData.map { data in
            "\(data["domain"] as? String ?? "").\(data["service"] as? String ?? "")"
        }
    }
}
