import Foundation
@testable import HAAPI

enum TestError: Error {
    case timedOut
}

func testConfiguration(
    heartbeatInterval: Duration = .seconds(60),
    heartbeatTimeout: Duration = .seconds(5),
    accessTokenProvider: @escaping @Sendable () async throws -> String = { "test-token" }
) -> HAAPIConfiguration {
    HAAPIConfiguration(
        webSocketURLProvider: { URL(string: "wss://example.com/api/websocket")! },
        accessTokenProvider: accessTokenProvider,
        heartbeatInterval: heartbeatInterval,
        heartbeatTimeout: heartbeatTimeout,
        reconnectPolicy: HAAPIReconnectPolicy(
            initialDelay: .milliseconds(1),
            maxDelay: .milliseconds(5),
            multiplier: 2,
            jitterRange: 1 ... 1
        )
    )
}

func waitUntil(
    timeout: Duration = .seconds(5),
    _ condition: @Sendable () async -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if await condition() {
            return
        }
        try await Task.sleep(for: .milliseconds(5))
    }
    throw TestError.timedOut
}

func waitForConnected(_ connection: HAAPIConnection) async throws {
    try await waitUntil {
        if case .connected = await connection.state {
            return true
        }
        return false
    }
}

func jsonObject(in frame: String) -> [String: Any]? {
    try? JSONSerialization.jsonObject(with: Data(frame.utf8)) as? [String: Any]
}

func commandID(in frame: String) -> Int? {
    jsonObject(in: frame)?["id"] as? Int
}

func commandType(in frame: String) -> String? {
    jsonObject(in: frame)?["type"] as? String
}

/// Collects elements from concurrent producers for later assertions.
actor Collector<Element: Sendable> {
    private(set) var elements: [Element] = []

    var count: Int { elements.count }

    func append(_ element: Element) {
        elements.append(element)
    }
}

/// Starts recording the connection's state stream; returns the collector and the recording task.
func recordStates(of connection: HAAPIConnection) async -> (Collector<HAAPIConnectionState>, Task<Void, Never>) {
    let collector = Collector<HAAPIConnectionState>()
    let stream = await connection.states()
    let task = Task {
        for await state in stream {
            await collector.append(state)
        }
    }
    return (collector, task)
}
