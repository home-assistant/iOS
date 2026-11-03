import Foundation
import PromiseKit
@testable import Shared
import SharedTesting
import Testing

/// Firing a scanned tag: servers too old for the `scan_tag` webhook get a `tag_scanned` event, newer
/// ones the webhook. Everything is read on the test's task, so each test gets its own environment.
@Suite(.isolatedEnvironment)
struct TagManagerFireEventTests {
    @Test func eachServerGetsTheMechanismItSupports() async throws {
        let webhooks = FakeWebhookManager()
        Current.webhooks = webhooks
        let servers = FakeServerManager()
        Current.servers = servers
        let modern = servers.addFake()
        let legacy = servers.add(
            identifier: .init(rawValue: "legacy"),
            serverInfo: with(ServerInfo.fake()) { $0.version = Version(major: 0, minor: 110, patch: 0) }
        )
        for server in [modern, legacy] {
            Current.cachedApis[server.identifier] = HomeAssistantAPI(server: server)
        }

        var webhookTags: [String] = []
        webhooks.sendRequestHandler = { _, _, request, seal in
            webhookTags.append((request.data as? [String: Any])?["tag_id"] as? String ?? "")
            seal.fulfill(())
        }
        var events: [String] = []
        webhooks.sendEphemeralHandler = { _, request in
            let data = request.data as? [String: Any]
            events.append(data?["event_type"] as? String ?? "")
            return [String: Any]()
        }

        try await EmptyTagManager().fireEvent(tag: "tag-1").asyncValue()
        #expect(webhookTags == ["tag-1"])
        #expect(events == ["tag_scanned"])
    }

    @Test func theEmptyManagerHasNoNFC() async {
        let manager = EmptyTagManager()
        #expect(!manager.isNFCAvailable)
        if case .unhandled = manager.handle(userActivity: NSUserActivity(activityType: "x")) {} else {
            Issue.record("expected unhandled")
        }
        await #expect(throws: TagManagerError.self) { try await manager.readNFC().asyncValue() }
        await #expect(throws: TagManagerError.self) { try await manager.writeNFC(value: "v").asyncValue() }
        await #expect(throws: TagManagerError.self) { try await manager.writeRandomNFC().asyncValue() }
        await #expect(throws: TagManagerError.self) {
            try await manager.writeNFC(deeplink: URL(string: "homeassistant://x")!, alertMessage: "Hold").asyncValue()
        }
        for error in [TagManagerError.nfcUnavailable, .notHomeAssistantTag, .invalidURL] {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }
}
