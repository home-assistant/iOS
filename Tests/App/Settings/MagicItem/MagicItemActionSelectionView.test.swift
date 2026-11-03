import Foundation
import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Lays the behavior picker out for every kind of behavior, so each one's extra rows (path, URL,
/// action, pipeline, script) render and prefill, edits them, and loads a server's actions into the
/// "perform action" picker through a mocked connection.
///
/// `.sharedState`: the test swaps `Current.database`, `Current.servers` and the cached API.
@Suite(.sharedState)
@MainActor
struct MagicItemActionSelectionViewTests {
    private final class ActionBox {
        var action: ItemAction?
        var binding: Binding<ItemAction?> {
            Binding(get: { self.action }, set: { self.action = $0 })
        }
    }

    private func withWorld(_ body: (String, HAMockConnection) async throws -> Void) async throws {
        let previousServers = Current.servers
        let manager = FakeServerManager(initial: 1)
        let server = manager.all[0]
        let serverId = server.identifier.rawValue
        let connection = HAMockConnection()
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        Current.servers = manager
        defer {
            // A request still pending fails, which ends the loader waiting on it.
            let leftovers = connection.pendingRequests
            connection.pendingRequests.removeAll()
            leftovers.forEach { $0.completion(.failure(.internal(debugDescription: "test ended"))) }
            Current.resetAPICache(for: [server.identifier])
            Current.servers = previousServers
        }
        try await SettingsTestDatabase.with({ db in
            try HAAppEntity(
                id: ServerEntity.uniqueId(serverId: serverId, entityId: "script.night"),
                entityId: "script.night",
                serverId: serverId,
                domain: "script",
                name: "Night",
                icon: nil,
                rawDeviceClass: nil
            ).insert(db)
            try AssistPipelines(
                serverId: serverId,
                preferredPipeline: "local",
                pipelines: [.init(id: "local", name: "Home Assistant")]
            ).insert(db)
        }) { _ in
            try await body(serverId, connection)
        }
    }

    private func show(_ item: MagicItem, _ box: ActionBox) async -> SettingsScreenHarness {
        await SettingsScreenHarness.show(List {
            Section {
                MagicItemActionSelectionView(
                    title: "Tap",
                    item: item,
                    supportedFeatures: nil,
                    defaultAction: item.defaultTapAction,
                    action: box.binding
                )
            }
        })
    }

    /// Answers every request the "perform action" picker sends, the follow-up translation request
    /// included, until none has been pending for several run-loop turns, so its loader finishes before
    /// the screen closes and the environment is restored. Returns the request types it answered.
    @discardableResult
    private func drain(_ connection: HAMockConnection, _ harness: SettingsScreenHarness) async -> [HARequestType] {
        var answered: [HARequestType] = []
        var quietTurns = 0
        let deadline = Date().addingTimeInterval(10)
        while quietTurns < 5, Date() < deadline {
            if connection.pendingRequests.isEmpty {
                quietTurns += 1
            } else {
                quietTurns = 0
                let pending = connection.pendingRequests.removeFirst()
                answered.append(pending.request.type)
                if pending.request.type == .getServices {
                    pending.completion(.success(.dictionary([
                        "light": ["turn_on": ["name": "Turn on"], "turn_off": [:]],
                    ])))
                } else {
                    pending.completion(.failure(.internal(debugDescription: "unsupported")))
                }
            }
            await harness.settle(1)
        }
        #expect(connection.pendingRequests.isEmpty, "the action picker kept sending requests")
        return answered
    }

    @Test func rendersEveryBehaviorWithItsExtraRows() async throws {
        try await withWorld { serverId, connection in
            let light = MagicItem(id: "light.kitchen", serverId: serverId, type: .entity)
            let actions: [ItemAction?] = [
                nil, .default, .moreInfoDialog, .toggle, .mainAction, .turnOn, .turnOff, .nothing,
                .performAction(serverId, "light.turn_on", "{\"brightness\": 10}"),
                .runScript(serverId, "script.night"),
                .runScript(serverId, "script.missing"),
            ]
            for action in actions {
                let box = ActionBox()
                box.action = action
                let harness = await show(light, box)
                #expect(harness.rows.count >= 1)
                let answered = await drain(connection, harness)
                if case .performAction = action {
                    // The action picker asks for the server's actions, icons and language.
                    #expect(answered.contains(.getServices))
                } else {
                    #expect(answered.isEmpty)
                }
                await harness.close()
            }
        }
    }

    @Test func typingAPathOrURLUpdatesTheBehavior() async throws {
        try await withWorld { serverId, _ in
            let item = MagicItem(id: "script.night", serverId: serverId, type: .script)

            let navigate = ActionBox()
            navigate.action = .navigate("/lovelace/0")
            var harness = await show(item, navigate)
            #expect(harness.rows.count == 2)
            await harness.type("/lovelace/kitchen")
            #expect(navigate.action == .navigate("/lovelace/kitchen"))
            await harness.close()

            let url = ActionBox()
            url.action = .url("https://example.com")
            harness = await show(item, url)
            await harness.type("https://www.home-assistant.io")
            #expect(url.action == .url("https://www.home-assistant.io"))
            await harness.close()
        }
    }

    @Test func assistBehaviorTogglesListening() async throws {
        try await withWorld { serverId, _ in
            let item = MagicItem(id: "script.night", serverId: serverId, type: .script)
            let box = ActionBox()
            box.action = .assist(serverId, "local", true)
            let harness = await show(item, box)
            #expect(harness.rows.count == 3)
            await harness.toggleSwitches()
            #expect(box.action == .assist(serverId, "local", false))
            await harness.close()
        }
    }

    /// Typing the action data writes a "perform action" behavior that carries it.
    @Test func typingThePayloadUpdatesThePerformAction() async throws {
        try await withWorld { serverId, connection in
            let item = MagicItem(id: "light.kitchen", serverId: serverId, type: .entity)
            let box = ActionBox()
            box.action = .performAction(serverId, "light.turn_on", "")
            let harness = await show(item, box)
            await #expect(harness.waitUntil { harness.rows.count >= 3 })

            let payload = "{\"brightness\": 20}"
            await harness.type(payload)
            for textView in harness.views(of: UITextView.self) {
                textView.text = payload
                textView.delegate?.textViewDidChange?(textView)
            }
            await harness.settle()
            #expect(box.action == .performAction(serverId, "light.turn_on", payload))
            let answered = await drain(connection, harness)
            #expect(answered.contains(.getServices))
            await harness.close()
        }
    }

    /// A script behavior whose entity cannot be read keeps the behavior and only logs.
    @Test func aScriptThatCannotBeReadIsNotPrefilled() async throws {
        try await withWorld { serverId, _ in
            Current.database = { try! DatabaseQueue() }
            let item = MagicItem(id: "script.night", serverId: serverId, type: .script)
            let box = ActionBox()
            box.action = .runScript(serverId, "script.night")
            let harness = await show(item, box)
            #expect(box.action == .runScript(serverId, "script.night"))
            await harness.close()
        }
    }

    @Test func performActionPickerLoadsTheServersActions() async throws {
        try await withWorld { serverId, connection in
            var selected: String? = "light.turn_on"
            let harness = await SettingsScreenHarness.show(List {
                ServerActionPicker(
                    serverId: serverId,
                    selectedActionId: Binding(get: { selected }, set: { selected = $0 })
                )
                ServerActionPicker(serverId: "no-such-server", selectedActionId: .constant("light.toggle"))
            })

            // The services answer; icons and translations fail, which the picker tolerates.
            var answered = 0
            while answered < 6, await harness.waitUntil(timeout: 2, { !connection.pendingRequests.isEmpty }) {
                let pending = connection.pendingRequests.removeFirst()
                if pending.request.type == .getServices {
                    pending.completion(.success(.dictionary([
                        "light": ["turn_on": ["name": "Turn on"], "turn_off": [:]],
                    ])))
                } else {
                    pending.completion(.failure(.internal(debugDescription: "unsupported")))
                }
                answered += 1
                await harness.settle()
            }
            #expect(answered >= 1)

            // The row opens the list, which offers the loaded actions.
            await harness.tapRow(IndexPath(item: 0, section: 0))
            await #expect(harness.waitUntil(timeout: 5) { harness.presented != nil })
            if await harness.waitUntil(timeout: 5, { harness.rows.count >= 2 }) {
                await harness.tapRow(harness.rows[harness.rows.count - 1])
            }
            await harness.dismissPresented()
            await harness.close()
        }
    }
}
