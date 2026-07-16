import Foundation
@testable import HAAPI
import Testing

@Suite struct HAAPIConnectionReconnectTests {
    @Test func reconnectsAndResubscribesOnSameStream() async throws {
        let transport1 = MockTransport.authenticating()
        let transport2 = MockTransport.authenticating()
        let factory = MockTransportFactory(transports: [transport1, transport2])
        let connection = HAAPIConnection(configuration: testConfiguration(), transportFactory: factory)

        let events = Collector<HAAPIJSONValue>()
        let stream = await connection.subscribe(command: "subscribe_entities")
        let consumer = Task {
            for try await event in stream {
                await events.append(event)
            }
        }

        await connection.connect()
        try await waitUntil { transport1.sentFrames.contains { commandType(in: $0) == "subscribe_entities" } }
        let firstID = try #require(
            transport1.sentFrames.first { commandType(in: $0) == "subscribe_entities" }.flatMap(commandID(in:))
        )
        transport1.enqueue("{\"id\": \(firstID), \"type\": \"event\", \"event\": 1}")
        try await waitUntil { await events.count == 1 }

        // Drop the socket: the subscription must be re-issued with a NEW id on the next session
        // while the consumer keeps iterating the same stream.
        transport1.failNow()
        try await waitUntil { transport2.sentFrames.contains { commandType(in: $0) == "subscribe_entities" } }
        let secondID = try #require(
            transport2.sentFrames.first { commandType(in: $0) == "subscribe_entities" }.flatMap(commandID(in:))
        )
        #expect(secondID > firstID)

        transport2.enqueue("{\"id\": \(secondID), \"type\": \"event\", \"event\": 2}")
        try await waitUntil { await events.count == 2 }
        #expectawait (events.elements == [.int(1), .int(2)])
        #expect(factory.makeCount == 2)

        consumer.cancel()
        await connection.disconnect()
    }

    @Test func inFlightRequestIsResentAfterReconnect() async throws {
        // Transport 1 accepts the command but dies before answering.
        let transport1 = MockTransport.authenticating(onCommand: { _, _, _ in [] })
        let transport2 = MockTransport.authenticating(onCommand: { id, _, _ in
            ["{\"id\": \(id), \"type\": \"result\", \"success\": true, \"result\": \"answered-after-reconnect\"}"]
        })
        let factory = MockTransportFactory(transports: [transport1, transport2])
        let connection = HAAPIConnection(configuration: testConfiguration(), transportFactory: factory)
        await connection.connect()
        try await waitForConnected(connection)

        let pending = Task { try await connection.send(command: "slow_command") }
        try await waitUntil { transport1.sentFrames.contains { commandType(in: $0) == "slow_command" } }
        transport1.failNow()

        #expecttry await (pending.value == .string("answered-after-reconnect"))
        #expect(factory.makeCount == 2)
        await connection.disconnect()
    }

    @Test func backoffAttemptsGrowAndResetAfterSuccess() async throws {
        let dead1 = MockTransport()
        dead1.failNow()
        let dead2 = MockTransport()
        dead2.failNow()
        let live1 = MockTransport.authenticating()
        let live2 = MockTransport.authenticating()
        let factory = MockTransportFactory(transports: [dead1, dead2, live1, live2])
        let connection = HAAPIConnection(configuration: testConfiguration(), transportFactory: factory)

        let (states, recording) = await recordStates(of: connection)
        await connection.connect()
        try await waitForConnected(connection)

        // Two dead attempts, then connected: attempts 1 and 2 recorded.
        var attempts = await states.elements.compactMap { state -> Int? in
            if case let .disconnected(reason: .waitingToReconnect(attempt, _)) = state {
                return attempt
            }
            return nil
        }
        #expect(attempts == [1, 2])

        // Drop the live session: the next reconnect must start over at attempt 1.
        live1.failNow()
        try await waitUntil { factory.makeCount == 4 }
        try await waitForConnected(connection)

        attempts = await states.elements.compactMap { state -> Int? in
            if case let .disconnected(reason: .waitingToReconnect(attempt, _)) = state {
                return attempt
            }
            return nil
        }
        #expect(attempts == [1, 2, 1])

        recording.cancel()
        await connection.disconnect()
    }
}
