import Foundation
@testable import HAAPI
import Testing

@Suite struct HAAPIConnectionHeartbeatTests {
    @Test func answeredPingsKeepConnectionAlive() async throws {
        let transport = MockTransport.authenticating(onCommand: { id, type, _ in
            if type == "ping" {
                return ["{\"id\": \(id), \"type\": \"pong\"}"]
            }
            return ["{\"id\": \(id), \"type\": \"result\", \"success\": true, \"result\": null}"]
        })
        let factory = MockTransportFactory(transports: [transport])
        let connection = HAAPIConnection(
            configuration: testConfiguration(
                heartbeatInterval: .milliseconds(20),
                heartbeatTimeout: .milliseconds(500)
            ),
            transportFactory: factory
        )
        await connection.connect()
        try await waitForConnected(connection)

        try await waitUntil { transport.sentFrames.filter { commandType(in: $0) == "ping" }.count >= 2 }
        if case .connected = await connection.state {} else {
            Issue.record("Expected the connection to stay connected while pings are answered")
        }
        #expect(factory.makeCount == 1)
        await connection.disconnect()
    }

    @Test func missedPongTearsDownAndReconnects() async throws {
        // Transport 1 swallows pings; transport 2 answers them.
        let transport1 = MockTransport.authenticating(onCommand: { id, type, _ in
            if type == "ping" {
                return []
            }
            return ["{\"id\": \(id), \"type\": \"result\", \"success\": true, \"result\": null}"]
        })
        let transport2 = MockTransport.authenticating(onCommand: { id, type, _ in
            if type == "ping" {
                return ["{\"id\": \(id), \"type\": \"pong\"}"]
            }
            return ["{\"id\": \(id), \"type\": \"result\", \"success\": true, \"result\": null}"]
        })
        let factory = MockTransportFactory(transports: [transport1, transport2])
        let connection = HAAPIConnection(
            configuration: testConfiguration(heartbeatInterval: .milliseconds(20), heartbeatTimeout: .milliseconds(30)),
            transportFactory: factory
        )
        await connection.connect()
        try await waitForConnected(connection)

        try await waitUntil { factory.makeCount == 2 }
        try await waitForConnected(connection)
        #expect(transport1.closeCode != nil)
        await connection.disconnect()
    }
}
