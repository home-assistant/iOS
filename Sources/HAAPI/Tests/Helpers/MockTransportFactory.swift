import Foundation
@testable import HAAPI

/// Hands out one scripted transport per connection attempt, so reconnect tests can script
/// attempt #1 failing and attempt #2 succeeding. When exhausted it returns immediately-dead
/// transports.
final class MockTransportFactory: HAAPITransportFactory, @unchecked Sendable {
    private let lock = NSLock()
    private var queue: [MockTransport]
    private var made = 0

    init(transports: [MockTransport]) {
        self.queue = transports
    }

    var makeCount: Int { lock.withLock { made } }

    func makeTransport(request: URLRequest, session: URLSession) -> any HAAPITransport {
        lock.withLock {
            made += 1
            guard !queue.isEmpty else {
                let dead = MockTransport()
                dead.failNow()
                return dead
            }
            return queue.removeFirst()
        }
    }
}
