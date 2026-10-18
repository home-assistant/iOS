import Foundation
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import Testing

/// Covers which server an action runs against, in particular for a shortcut synced from another
/// device, which names a server identifier this installation never issued.
///
/// The availability guard sits inside each test rather than on the suite: `@Suite` cannot be applied
/// to a type marked `@available`, and the intent is iOS 17.
@Suite(.serialized)
struct PerformActionAppIntentTests {
    private static let foreignIdentifier = "identifier-from-another-device"

    private func withServers(
        count: Int,
        _ body: ([Server], [HAMockConnection]) async throws -> Void
    ) async throws {
        let previousServers = Current.servers
        let previousApis = Current.cachedApis
        defer {
            Current.servers = previousServers
            Current.cachedApis = previousApis
        }

        let manager = FakeServerManager(initial: count)
        Current.servers = manager

        var connections = [HAMockConnection]()
        var apis = [Identifier<Server>: HomeAssistantAPI]()
        for server in manager.all {
            let connection = HAMockConnection()
            let api = HomeAssistantAPI(server: server)
            api.connection = connection
            connections.append(connection)
            apis[server.identifier] = api
        }
        Current.cachedApis = apis

        try await body(manager.all, connections)
    }

    /// Runs `perform()` against a mocked connection, answering the one request it sends.
    ///
    /// The intent is async while the connection records requests synchronously, so the call is
    /// started first and the request answered once it lands. A request that never arrives fails the
    /// test rather than leaving it awaiting an intent that is itself blocked on the connection.
    @available(iOS 17.0, *)
    private func performAndCaptureRequest(
        _ intent: PerformActionAppIntent,
        connection: HAMockConnection
    ) async throws -> HARequest {
        let task = Task { try await intent.perform() }
        do {
            let pending = try await firstRequest(on: connection)
            pending.completion(.success(.empty))
            _ = try await task.value
            return pending.request
        } catch {
            task.cancel()
            throw error
        }
    }

    /// The first request sent on `connection`, once it has been sent.
    private func firstRequest(on connection: HAMockConnection) async throws -> HAMockConnection.PendingRequest {
        for _ in 0 ..< 300 {
            if let pending = connection.pendingRequests.first {
                return pending
            }
            try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
        }
        throw RequestNeverSent()
    }

    private struct RequestNeverSent: Error {}

    /// A shortcut synced from another device names a server this installation never issued. With a
    /// single server set up there is only one server it can mean, so the action runs.
    @Test func runsAnActionFromAShortcutSyncedFromAnotherDevice() async throws {
        guard #available(iOS 17.0, *) else { return }
        try await withServers(count: 1) { _, connections in
            let intent = PerformActionAppIntent()
            intent.server = IntentServerAppEntity(identifier: .init(rawValue: Self.foreignIdentifier))
            intent.action = try #require(IntentActionEntity(identifier: "\(Self.foreignIdentifier)::fan.turn_on"))
            intent.payload = #"{"entity_id": "fan.probreeze"}"#

            let request = try await performAndCaptureRequest(intent, connection: connections[0])
            #expect(request.data["domain"] as? String == "fan")
            #expect(request.data["service"] as? String == "turn_on")
            #expect((request.data["service_data"] as? [String: Any])?["entity_id"] as? String == "fan.probreeze")
        }
    }

    /// With several servers set up there is nothing to fall back on, so an action belonging to a
    /// different server than the one picked is still refused.
    @Test func refusesAnActionBelongingToAnotherServer() async throws {
        guard #available(iOS 17.0, *) else { return }
        try await withServers(count: 2) { servers, _ in
            let intent = PerformActionAppIntent()
            intent.server = IntentServerAppEntity(from: servers[0])
            intent.action = try #require(
                IntentActionEntity(identifier: "\(servers[1].identifier.rawValue)::fan.turn_on")
            )
            intent.payload = "{}"

            await #expect(throws: ShortcutAppIntentError.self) {
                _ = try await intent.perform()
            }
        }
    }

    /// Nothing resolves when no server is set up, whatever the shortcut names.
    @Test func refusesWhenNoServerIsSetUp() async throws {
        guard #available(iOS 17.0, *) else { return }
        try await withServers(count: 0) { _, _ in
            let intent = PerformActionAppIntent()
            intent.server = IntentServerAppEntity(identifier: .init(rawValue: Self.foreignIdentifier))
            intent.action = try #require(IntentActionEntity(identifier: "\(Self.foreignIdentifier)::fan.turn_on"))
            intent.payload = "{}"

            await #expect(throws: ShortcutAppIntentError.self) {
                _ = try await intent.perform()
            }
        }
    }
}
