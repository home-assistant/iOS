import Foundation
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import Testing

@MainActor
struct ServerReauthenticationTests {
    /// A connection already up stays signed in as before, which can be another user, so signing in again connects
    /// anew with the token just signed in with.
    @Test func reconnectingAsksForTheTokenAgain() {
        let server = Server.fake(identifier: "server-signed-in-to-again")
        var tokensFetched = 0
        let connection = HAMockConnection(configuration: .init(
            connectionInfo: { try? HAConnectionInfo(url: URL(string: "http://127.0.0.1:8123")!) },
            fetchAuthToken: { completion in
                tokensFetched += 1
                completion(.success("new-token"))
            }
        ))
        connection.setState(.ready(version: "2026.10.0"), waitForQueue: false)
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.cachedApis[server.identifier] = api
        defer { Current.cachedApis[server.identifier] = nil }

        ServerReauthentication.reconnect(to: server)

        #expect(tokensFetched == 1)
        #expect(connection.state == .ready(version: "1.0-mock"))
    }
}
