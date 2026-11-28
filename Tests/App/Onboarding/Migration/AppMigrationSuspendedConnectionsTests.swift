import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import Testing

/// While the setup is being handed over, nothing of this app may reach the server.
struct AppMigrationSuspendedConnectionsTests {
    @Test func nothingConnectsOrSendsWhileSuspended() throws {
        let api = HomeAssistantAPI(server: .fake())
        HomeAssistantAPI.connectionsSuspended = true
        defer { HomeAssistantAPI.connectionsSuspended = false }
        #expect(HomeAssistantAPI.connectionsSuspended)

        api.connectWebSocketIfNeeded()
        let connect = api.Connect(reason: .warm)
        #expect(connect.isFulfilled)

        let request = WebhookRequest(type: "get_config", data: [:])
        let ephemeral: Promise<[String: Any]> = Current.webhooks.sendEphemeral(server: api.server, request: request)
        let sent = Current.webhooks.send(server: api.server, request: request)
        let passive = Current.webhooks.sendPassive(server: api.server, request: request)
        for promise in [ephemeral.asVoid(), sent, passive] {
            #expect(promise.isRejected)
            #expect(promise.error as? WebhookError == .connectionsSuspended)
        }
        #expect(WebhookError.connectionsSuspended.isCancelled)
        #expect(!WebhookError.connectionsSuspended.localizedDescription.isEmpty)
    }

    @Test func theHandoffPhaseInTheAppGroupSuspendsEveryProcess() {
        defer { AppMigrationHandoffStore.save(nil) }
        AppMigrationHandoffStore.save(.handedOff(sessionID: UUID()))
        #expect(AppMigrationHandoff.isActive)
        #expect(HomeAssistantAPI.connectionsSuspended)
        AppMigrationHandoffStore.save(nil)
        #expect(!AppMigrationHandoff.isActive)
        #expect(!HomeAssistantAPI.connectionsSuspended)
    }
}
