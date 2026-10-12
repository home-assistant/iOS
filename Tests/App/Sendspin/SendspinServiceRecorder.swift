import Foundation
@testable import HomeAssistant

/// Collects what a player service reports, and waits for a report to arrive.
final class SendspinServiceRecorder: @unchecked Sendable {
    struct Timeout: Error {}

    private let lock = NSLock()
    private var statuses: [SendspinPlayerStatus] = []
    private var events: [SendspinSessionEvent] = []

    func record(_ status: SendspinPlayerStatus) {
        lock.withLock { statuses.append(status) }
    }

    func record(_ event: SendspinSessionEvent) {
        lock.withLock { events.append(event) }
    }

    var recordedEvents: [SendspinSessionEvent] {
        lock.withLock { events }
    }

    /// Polls rather than waits on a signal: the reports arrive from tasks the test does not own.
    func wait(
        timeout: TimeInterval = 5,
        for predicate: (SendspinPlayerStatus) -> Bool
    ) async throws -> SendspinPlayerStatus {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let match = lock.withLock({ statuses.last(where: predicate) }) {
                return match
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        throw Timeout()
    }

    func listeningPort() async throws -> UInt16 {
        let status = try await wait { status in
            if case .listening = status { return true }
            return false
        }
        guard case let .listening(port) = status else { throw Timeout() }
        return port
    }
}
