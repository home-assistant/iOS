import Foundation
@testable import HomeAssistant
import Network
import Testing

/// Exercises the listener end to end over loopback. Framing, the sequential read loop and the
/// describe/info exchange are what a Wyoming client depends on, and none of them are visible from a
/// codec test on its own.
struct WyomingServerTests {
    private enum TestError: Error {
        case listenerFailed(String)
        case timedOut
        case connectionClosed
    }

    /// The listener reports its state on its own queue, so the port is picked up through a lock
    /// rather than by awaiting the actor.
    private final class StateRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var port: UInt16?
        private var failure: String?

        func record(_ state: WyomingServerState) {
            lock.lock()
            defer { lock.unlock() }
            switch state {
            case let .running(port):
                self.port = port
            case let .failed(message):
                failure = message
            case .stopped, .starting:
                break
            }
        }

        func boundPort(timeout: TimeInterval = 10) async throws -> UInt16 {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                lock.lock()
                let port = port
                let failure = failure
                lock.unlock()

                if let failure { throw TestError.listenerFailed(failure) }
                if let port { return port }
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            throw TestError.timedOut
        }
    }

    private func send(_ event: WyomingEvent, over connection: NWConnection) async throws {
        let data = try WyomingEventCodec.encode(event)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func receiveEvent(from connection: NWConnection, buffer: inout Data) async throws -> WyomingEvent {
        while true {
            if let event = try WyomingEventCodec.decode(from: &buffer) {
                return event
            }
            let chunk: Data = try await withCheckedThrowingContinuation { continuation in
                connection
                    .receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { content, _, isComplete, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else if let content, !content.isEmpty {
                            continuation.resume(returning: content)
                        } else if isComplete {
                            continuation.resume(throwing: TestError.connectionClosed)
                        } else {
                            continuation.resume(returning: Data())
                        }
                    }
            }
            buffer.append(chunk)
        }
    }

    @Test func answersDescribeWithInfo() async throws {
        let recorder = StateRecorder()
        let server = WyomingServer(
            port: .any,
            serviceName: "Wyoming server tests",
            fallbackLocale: Locale(identifier: "en-US"),
            advertisesOverBonjour: false,
            onStateChange: { recorder.record($0) }
        )
        await server.start()
        defer { Task { await server.stop() } }

        let boundPort = try await recorder.boundPort()
        let port = try #require(NWEndpoint.Port(rawValue: boundPort))
        let connection = NWConnection(host: .ipv4(.loopback), port: port, using: .tcp)
        connection.start(queue: .global())
        defer { connection.cancel() }

        try await send(WyomingEvent(kind: .describe), over: connection)
        var buffer = Data()
        let event = try await receiveEvent(from: connection, buffer: &buffer)

        #expect(event.kind == .info)

        // Every installed voice is advertised, and the simulator always has some, so the payload is
        // proof the catalog was actually built rather than an empty envelope.
        struct Info: Decodable {
            struct Program: Decodable {
                let name: String
                let installed: Bool
            }

            let tts: [Program]
        }
        let info = try event.decodeData(Info.self)
        #expect(info.tts.first?.installed == true)
    }
}
