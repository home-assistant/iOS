import Foundation
import Shared

/// The plain `ws://` transport Sendspin runs on. Confidentiality and integrity come from the Noise
/// layer inside the payloads, so TLS is deliberately absent here.
///
/// The delegate queue is the main queue and every caller runs on the main actor, so the state below
/// is only ever touched from one thread.
final class SendspinWebSocketTransport: NSObject {
    enum Frame {
        case text(String)
        case binary(Data)
    }

    enum TransportError: Error {
        case closed
        case unexpectedFrame
    }

    private let url: URL
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var openContinuation: CheckedContinuation<Void, Error>?
    private var isOpen = false

    init(url: URL) {
        self.url = url
        super.init()
    }

    func connect() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
        let task = session.webSocketTask(with: url)
        self.session = session
        self.task = task
        task.resume()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            if isOpen {
                continuation.resume()
            } else {
                openContinuation = continuation
            }
        }
    }

    /// Enqueues a frame synchronously.
    ///
    /// This is deliberately not `async`: every encrypted frame carries the Noise counter it was
    /// sealed with, so the order frames are handed to the socket must match the order they were
    /// encrypted in. Awaiting transmission would let two senders interleave between those two
    /// steps, and the peer would reject the reordered frames.
    func send(_ frame: Frame) throws {
        guard let task else { throw TransportError.closed }
        let message: URLSessionWebSocketTask.Message
        switch frame {
        case let .text(string):
            message = .string(string)
        case let .binary(data):
            message = .data(data)
        }
        task.send(message) { error in
            guard let error else { return }
            // A failed send also breaks the receive loop, which is where the session is torn down.
            Current.Log.error("Sendspin failed to send a frame: \(error)")
        }
    }

    func receive() async throws -> Frame {
        guard let task else { throw TransportError.closed }
        switch try await task.receive() {
        case let .string(string):
            return .text(string)
        case let .data(data):
            return .binary(data)
        @unknown default:
            throw TransportError.unexpectedFrame
        }
    }

    /// RFC 6455 ping, the protocol's expected liveness mechanism. Control frames are not Sendspin
    /// messages and are never encrypted.
    func ping() async throws {
        guard let task else { throw TransportError.closed }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.sendPing { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func close() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        isOpen = false
        resumeOpenContinuation(with: TransportError.closed)
    }

    private func resumeOpenContinuation(with error: Error?) {
        guard let continuation = openContinuation else { return }
        openContinuation = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }
}

extension SendspinWebSocketTransport: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        isOpen = true
        resumeOpenContinuation(with: nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        isOpen = false
        resumeOpenContinuation(with: error ?? TransportError.closed)
    }
}
