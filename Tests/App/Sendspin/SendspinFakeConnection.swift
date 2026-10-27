import Foundation
@testable import HomeAssistant

/// An in-memory WebSocket: the test plays the server by delivering frames and reading what the
/// session sent.
final class SendspinFakeConnection: SendspinFrameConnection, SendspinTestLink, @unchecked Sendable {
    struct Timeout: Error {}
    struct Closed: Error {}

    private let lock = NSLock()
    private var inbox: [SendspinWebSocketFrame] = []
    private var receiver: CheckedContinuation<SendspinWebSocketFrame, Error>?
    private var sent: [SendspinWebSocketFrame] = []
    private var sentWaiter: CheckedContinuation<SendspinWebSocketFrame?, Never>?
    private var closed = false

    var isClosed: Bool {
        lock.withLock { closed }
    }

    func start() async throws {}

    func receive() async throws -> SendspinWebSocketFrame {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if closed {
                lock.unlock()
                continuation.resume(throwing: Closed())
            } else if !inbox.isEmpty {
                let frame = inbox.removeFirst()
                lock.unlock()
                continuation.resume(returning: frame)
            } else {
                receiver = continuation
                lock.unlock()
            }
        }
    }

    func send(text: Data) {
        record(SendspinWebSocketFrame(kind: .text, data: text, receivedAt: 0))
    }

    func send(binary: Data) {
        record(SendspinWebSocketFrame(kind: .binary, data: binary, receivedAt: 0))
    }

    func close() {
        lock.lock()
        closed = true
        let pendingReceiver = receiver
        receiver = nil
        let pendingWaiter = sentWaiter
        sentWaiter = nil
        lock.unlock()
        pendingReceiver?.resume(throwing: Closed())
        pendingWaiter?.resume(returning: nil)
    }

    /// Hands the session a frame, as the server sending it.
    func deliver(_ kind: SendspinWebSocketFrame.Kind, _ data: Data) {
        let frame = SendspinWebSocketFrame(kind: kind, data: data, receivedAt: SendspinClock.nowMicroseconds())
        lock.lock()
        if let receiver {
            self.receiver = nil
            lock.unlock()
            receiver.resume(returning: frame)
        } else {
            inbox.append(frame)
            lock.unlock()
        }
    }

    /// The next frame the session sent, waiting for it if need be.
    func nextSent(timeout: TimeInterval) async throws -> SendspinWebSocketFrame {
        try await withThrowingTaskGroup(of: SendspinWebSocketFrame?.self) { group in
            group.addTask { await self.waitForSent() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw Timeout()
            }
            defer { group.cancelAll() }
            guard let frame = try await group.next() ?? nil else { throw Closed() }
            return frame
        }
    }

    private func waitForSent() async -> SendspinWebSocketFrame? {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                lock.lock()
                if !sent.isEmpty {
                    let frame = sent.removeFirst()
                    lock.unlock()
                    continuation.resume(returning: frame)
                } else if closed || Task.isCancelled {
                    lock.unlock()
                    continuation.resume(returning: nil)
                } else {
                    sentWaiter = continuation
                    lock.unlock()
                }
            }
        } onCancel: {
            lock.lock()
            let waiter = sentWaiter
            sentWaiter = nil
            lock.unlock()
            waiter?.resume(returning: nil)
        }
    }

    private func record(_ frame: SendspinWebSocketFrame) {
        lock.lock()
        if let sentWaiter {
            self.sentWaiter = nil
            lock.unlock()
            sentWaiter.resume(returning: frame)
        } else {
            sent.append(frame)
            lock.unlock()
        }
    }
}
