import Foundation
@testable import HAAPI
import Testing

@Suite struct HAAPIConnectionAuthTests {
    @Test func authenticatesSuccessfully() async throws {
        let transport = MockTransport.authenticating(haVersion: "2026.7.0")
        let factory = MockTransportFactory(transports: [transport])
        let connection = HAAPIConnection(configuration: testConfiguration(), transportFactory: factory)

        await connection.connect()
        try await waitUntil { await connection.state == .connected(haVersion: "2026.7.0") }

        let authFrame = try #require(transport.sentFrames.first)
        #expect(commandType(in: authFrame) == "auth")
        #expect(jsonObject(in: authFrame)?["access_token"] as? String == "test-token")
        await connection.disconnect()
    }

    @Test func authInvalidStopsWithoutRetrying() async throws {
        let transport = MockTransport(onSend: { text in
            guard commandType(in: text) == "auth" else { return [] }
            return ["{\"type\": \"auth_invalid\", \"message\": \"bad token\"}"]
        })
        transport.enqueue("{\"type\": \"auth_required\"}")
        let factory = MockTransportFactory(transports: [transport])
        let connection = HAAPIConnection(configuration: testConfiguration(), transportFactory: factory)

        let pendingSend = Task { try await connection.send(command: "get_states") }
        await connection.connect()

        await #expect(throws: HAAPIError.authenticationFailed(message: "bad token")) {
            _ = try await pendingSend.value
        }
        try await waitUntil {
            await connection.state == .disconnected(reason: .authenticationFailed(message: "bad token"))
        }
        // No reconnect attempt after a rejected token.
        try await Task.sleep(for: .milliseconds(50))
        #expect(factory.makeCount == 1)
    }

    @Test func tokenProviderFailureRetriesPerPolicy() async throws {
        let transports = [MockTransport.authenticating(), MockTransport.authenticating()]
        let factory = MockTransportFactory(transports: transports)
        let attempts = Collector<Int>()
        let connection = HAAPIConnection(
            configuration: testConfiguration(accessTokenProvider: {
                await attempts.append(1)
                if await attempts.count == 1 {
                    throw TestError.timedOut
                }
                return "test-token"
            }),
            transportFactory: factory
        )

        await connection.connect()
        // First attempt fails in the token provider, second succeeds.
        try await waitForConnected(connection)
        #expect(factory.makeCount == 2)
        await connection.disconnect()
    }
}
