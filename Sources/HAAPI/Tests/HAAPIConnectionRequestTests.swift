import Foundation
@testable import HAAPI
import Testing

@Suite struct HAAPIConnectionRequestTests {
    @Test func queuesRequestsUntilAuthenticated() async throws {
        let transport = MockTransport.authenticating()
        let factory = MockTransportFactory(transports: [transport])
        let connection = HAAPIConnection(configuration: testConfiguration(), transportFactory: factory)

        let pendingSend = Task { try await connection.send(command: "get_config") }
        try await Task.sleep(for: .milliseconds(20))
        #expect(transport.sentFrames.isEmpty)

        await connection.connect()
        let result = try await pendingSend.value
        #expect(result == .null)

        let frames = transport.sentFrames
        #expect(commandType(in: frames[0]) == "auth")
        #expect(commandType(in: frames[1]) == "get_config")
        #expecttry (#require(commandID(in: frames[1])) >= 1)
        await connection.disconnect()
    }

    @Test func correlatesOutOfOrderResults() async throws {
        let transport = MockTransport.authenticating(onCommand: { _, _, _ in [] })
        let factory = MockTransportFactory(transports: [transport])
        let connection = HAAPIConnection(configuration: testConfiguration(), transportFactory: factory)
        await connection.connect()
        try await waitForConnected(connection)

        let first = Task { try await connection.send(command: "first") }
        let second = Task { try await connection.send(command: "second") }
        try await waitUntil { transport.sentFrames.compactMap(commandID(in:)).count == 2 }

        let frames = transport.sentFrames
        let firstID = try #require(frames.first(where: { commandType(in: $0) == "first" }).flatMap(commandID(in:)))
        let secondID = try #require(frames.first(where: { commandType(in: $0) == "second" }).flatMap(commandID(in:)))
        #expect(secondID > firstID)

        // Reply to the second request first.
        transport.enqueue("{\"id\": \(secondID), \"type\": \"result\", \"success\": true, \"result\": \"B\"}")
        transport.enqueue("{\"id\": \(firstID), \"type\": \"result\", \"success\": true, \"result\": \"A\"}")

        #expecttry await (first.value == .string("A"))
        #expecttry await (second.value == .string("B"))
        await connection.disconnect()
    }

    @Test func serverErrorThrows() async throws {
        let transport = MockTransport.authenticating(onCommand: { id, _, _ in
            [
                "{\"id\": \(id), \"type\": \"result\", \"success\": false, \"error\": {\"code\": \"unknown_command\", \"message\": \"nope\"}}",
            ]
        })
        let factory = MockTransportFactory(transports: [transport])
        let connection = HAAPIConnection(configuration: testConfiguration(), transportFactory: factory)
        await connection.connect()

        await #expect(throws: HAAPIError.server(code: "unknown_command", message: "nope")) {
            _ = try await connection.send(command: "get_states")
        }
        await connection.disconnect()
    }

    @Test func decodeFailureLeavesConnectionUsable() async throws {
        let transport = MockTransport.authenticating(onCommand: { id, type, _ in
            if type == "get_states" {
                return ["{\"id\": \(id), \"type\": \"result\", \"success\": true, \"result\": {\"not\": \"an array\"}}"]
            }
            return ["{\"id\": \(id), \"type\": \"result\", \"success\": true, \"result\": null}"]
        })
        let factory = MockTransportFactory(transports: [transport])
        let connection = HAAPIConnection(configuration: testConfiguration(), transportFactory: factory)
        await connection.connect()

        do {
            _ = try await connection.send(HAAPIRequest<[HAAPIEntityState]>.getStates())
            Issue.record("Expected a decoding error")
        } catch let error as HAAPIError {
            guard case .decoding = error else {
                Issue.record("Expected .decoding, got \(error)")
                return
            }
        }

        // The connection survives a decode failure.
        let result = try await connection.send(command: "other")
        #expect(result == .null)
        await connection.disconnect()
    }

    @Test func disconnectFailsPendingRequests() async throws {
        let transport = MockTransport.authenticating(onCommand: { _, _, _ in [] })
        let factory = MockTransportFactory(transports: [transport])
        let connection = HAAPIConnection(configuration: testConfiguration(), transportFactory: factory)
        await connection.connect()
        try await waitForConnected(connection)

        let pending = Task { try await connection.send(command: "never_answered") }
        try await waitUntil { !transport.sentFrames.compactMap(commandID(in:)).isEmpty }
        await connection.disconnect()

        await #expect(throws: HAAPIError.cancelled) {
            _ = try await pending.value
        }
    }
}
