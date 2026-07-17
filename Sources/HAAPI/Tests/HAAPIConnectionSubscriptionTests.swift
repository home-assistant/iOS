import Foundation
@testable import HAAPI
import Testing

@Suite struct HAAPIConnectionSubscriptionTests {
    @Test func routesEventsToSubscriber() async throws {
        let transport = MockTransport.authenticating()
        let factory = MockTransportFactory(transports: [transport])
        let connection = HAAPIConnection(configuration: testConfiguration(), transportFactory: factory)
        await connection.connect()
        try await waitForConnected(connection)

        let events = Collector<HAAPIJSONValue>()
        let stream = await connection.subscribe(command: "subscribe_events", data: ["event_type": "state_changed"])
        let consumer = Task {
            for try await event in stream {
                await events.append(event)
            }
        }

        try await waitUntil { transport.sentFrames.contains { commandType(in: $0) == "subscribe_events" } }
        let subscribeFrame = try #require(transport.sentFrames.first { commandType(in: $0) == "subscribe_events" })
        let subscriptionID = try #require(commandID(in: subscribeFrame))
        #expect(jsonObject(in: subscribeFrame)?["event_type"] as? String == "state_changed")

        transport.enqueue("{\"id\": \(subscriptionID), \"type\": \"event\", \"event\": {\"n\": 1}}")
        transport.enqueue("{\"id\": \(subscriptionID), \"type\": \"event\", \"event\": {\"n\": 2}}")
        // An event for an unrelated id must not be delivered.
        transport.enqueue("{\"id\": 9999, \"type\": \"event\", \"event\": {\"n\": 3}}")

        try await waitUntil { await events.count == 2 }
        try await Task.sleep(for: .milliseconds(20))
        let received = await events.elements
        #expect(received == [.object(["n": .int(1)]), .object(["n": .int(2)])])

        consumer.cancel()
        await connection.disconnect()
    }

    @Test func cancellingConsumerSendsUnsubscribe() async throws {
        let transport = MockTransport.authenticating()
        let factory = MockTransportFactory(transports: [transport])
        let connection = HAAPIConnection(configuration: testConfiguration(), transportFactory: factory)
        await connection.connect()
        try await waitForConnected(connection)

        let stream = await connection.subscribe(command: "subscribe_entities")
        let consumer = Task {
            for try await _ in stream {}
        }
        try await waitUntil { transport.sentFrames.contains { commandType(in: $0) == "subscribe_entities" } }
        let subscriptionID = try #require(
            transport.sentFrames.first { commandType(in: $0) == "subscribe_entities" }.flatMap(commandID(in:))
        )

        consumer.cancel()
        try await waitUntil {
            transport.sentFrames.contains { frame in
                commandType(in: frame) == "unsubscribe_events"
                    && jsonObject(in: frame)?["subscription"] as? Int == subscriptionID
            }
        }
        await connection.disconnect()
    }

    @Test func failedSubscriptionResultThrows() async throws {
        let transport = MockTransport.authenticating(onCommand: { id, type, _ in
            if type == "subscribe_events" {
                return [
                    "{\"id\": \(id), \"type\": \"result\", \"success\": false, \"error\": {\"code\": \"not_allowed\", \"message\": \"denied\"}}",
                ]
            }
            return ["{\"id\": \(id), \"type\": \"result\", \"success\": true, \"result\": null}"]
        })
        let factory = MockTransportFactory(transports: [transport])
        let connection = HAAPIConnection(configuration: testConfiguration(), transportFactory: factory)
        await connection.connect()
        try await waitForConnected(connection)

        let stream = await connection.subscribe(command: "subscribe_events")
        await #expect(throws: HAAPIError.server(code: "not_allowed", message: "denied")) {
            for try await _ in stream {}
        }
        await connection.disconnect()
    }
}
