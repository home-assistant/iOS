#if os(iOS) && !targetEnvironment(macCatalyst)
import CoreVideo
import Foundation
import Network
@testable import Shared
import XCTest

/// Talks to a real `CameraStreamServer` listener over loopback TCP: the HTTP handshake, the
/// Basic auth gate, and frames being pushed to a connected client.
final class CameraStreamServerStreamingTests: XCTestCase {
    private static let preferenceKeys = ["camera_stream_port", "camera_stream_frame_rate", "camera_stream_username"]

    private var savedValues: [String: Any] = [:]
    private var server: CameraStreamServer!
    private var port = 0

    override func setUp() {
        super.setUp()
        let prefs = Current.settingsStore.prefs
        savedValues = [:]
        for key in Self.preferenceKeys {
            if let value = prefs.object(forKey: key) {
                savedValues[key] = value
            }
            prefs.removeObject(forKey: key)
        }
        server = CameraStreamServer()
        port = Int.random(in: 20000 ... 60000)
    }

    override func tearDown() {
        if let server {
            server.setActive(false)
            _ = waitUntil { !server.isActive }
        }
        server = nil
        let prefs = Current.settingsStore.prefs
        for key in Self.preferenceKeys {
            if let value = savedValues[key] {
                prefs.set(value, forKey: key)
            } else {
                prefs.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    func testSettingsDefaultsAndRoundTrip() {
        XCTAssertEqual(server.port, 8090)
        XCTAssertEqual(server.streamFrameRate, 15)
        XCTAssertEqual(server.username, "")

        server.port = port
        server.streamFrameRate = 24
        server.username = "viewer"

        XCTAssertEqual(server.port, port)
        XCTAssertEqual(server.streamFrameRate, 24)
        XCTAssertEqual(server.username, "viewer")
        if let streamURL = server.streamURL {
            XCTAssertTrue(streamURL.hasPrefix("http://"))
            XCTAssertTrue(streamURL.hasSuffix(":\(port)/camera"))
        }
    }

    func testInactiveServerHasNoClients() {
        XCTAssertFalse(server.isActive)
        XCTAssertFalse(server.isStreaming)
        XCTAssertEqual(server.clientCount, 0)
    }

    func testRequestWithoutCredentialsIsRejected() throws {
        server.port = port
        server.username = "viewer"
        activate()

        let reply = try XCTUnwrap(response(to: "GET /camera HTTP/1.1\r\nHost: localhost\r\n\r\n") {
            $0.contains("\r\n\r\n")
        })

        XCTAssertTrue(reply.hasPrefix("HTTP/1.1 401 Unauthorized"))
        XCTAssertTrue(reply.contains("WWW-Authenticate: Basic realm=\"Home Assistant Camera\""))
        XCTAssertEqual(server.clientCount, 0)
    }

    func testRequestWithWrongCredentialsIsRejected() throws {
        server.port = port
        server.username = "viewer"
        activate()

        let authorization = Data("intruder:guess".utf8).base64EncodedString()
        let request = "GET /camera HTTP/1.1\r\nHost: localhost\r\nAuthorization: Basic \(authorization)\r\n\r\n"
        let reply = try XCTUnwrap(response(to: request) { $0.contains("\r\n\r\n") })

        XCTAssertTrue(reply.hasPrefix("HTTP/1.1 401 Unauthorized"))
    }

    func testAuthorizedClientReceivesTheStreamAndFrames() throws {
        server.port = port
        server.username = "viewer"
        var stateChanges = 0
        server.onStateChange = { stateChanges += 1 }
        activate()

        let authorization = Data("viewer:\(server.password)".utf8).base64EncodedString()
        // Headers arriving in two segments must still be read as one request.
        let client = try XCTUnwrap(connectedClient(
            firstSegment: "GET /camera HTTP/1.1\r\nHost: localhost\r\n",
            secondSegment: "Authorization: Basic \(authorization)\r\n\r\n"
        ) { $0.contains("\r\n\r\n") })
        defer { client.cancel() }

        XCTAssertTrue(client.received.hasPrefix("HTTP/1.1 200 OK"))
        XCTAssertTrue(client.received.contains("Content-Type: multipart/x-mixed-replace; boundary=hacameraframe"))
        XCTAssertTrue(waitUntil { self.server.clientCount == 1 })
        XCTAssertTrue(server.isStreaming)

        let frame = try Self.pixelBuffer()
        server.handle(frame: frame)

        XCTAssertTrue(waitUntil { client.received.contains("--hacameraframe") })
        XCTAssertTrue(waitUntil { client.received.contains("Content-Type: image/jpeg") })
        XCTAssertGreaterThan(stateChanges, 0)

        server.setActive(false)
        XCTAssertTrue(waitUntil { !self.server.isActive && self.server.clientCount == 0 })
    }

    // MARK: - Helpers

    private func activate() {
        server.setActive(true)
        XCTAssertTrue(waitUntil { self.server.isActive })
    }

    /// Sends `request` and returns what came back once `isComplete` holds for it. The listener comes
    /// up asynchronously, so a connection that gets nothing back is retried.
    private func response(to request: String, isComplete: @escaping (String) -> Bool) -> String? {
        guard let client = connectedClient(firstSegment: request, secondSegment: nil, isComplete: isComplete) else {
            return nil
        }
        defer { client.cancel() }
        return client.received
    }

    private func connectedClient(
        firstSegment: String,
        secondSegment: String?,
        isComplete: @escaping (String) -> Bool
    ) -> StreamClient? {
        for _ in 0 ..< 20 {
            let client = StreamClient(port: port)
            client.start()
            client.send(firstSegment)
            if let secondSegment {
                client.send(secondSegment)
            }
            if waitUntil(timeout: 1, { isComplete(client.received) }) {
                return client
            }
            client.cancel()
        }
        return nil
    }

    /// Spins the main run loop while waiting, so main-queue work the server dispatches can run.
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }

    private static func pixelBuffer() throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, 32, 32, kCVPixelFormatType_32BGRA, nil, &buffer)
        XCTAssertEqual(status, kCVReturnSuccess)
        return try XCTUnwrap(buffer)
    }

    /// Minimal TCP client that accumulates everything the server sends.
    private final class StreamClient {
        private let connection: NWConnection
        private let queue = DispatchQueue(label: "camera-stream-test-client")
        private let lock = NSLock()
        private var buffer = Data()

        init(port: Int) {
            self.connection = NWConnection(
                host: "127.0.0.1",
                port: NWEndpoint.Port(rawValue: UInt16(port)) ?? .any,
                using: .tcp
            )
        }

        var received: String {
            lock.lock()
            defer { lock.unlock() }
            return String(decoding: buffer, as: UTF8.self)
        }

        func start() {
            connection.start(queue: queue)
            receive()
        }

        func send(_ string: String) {
            connection.send(content: Data(string.utf8), completion: .contentProcessed { _ in })
        }

        func cancel() {
            connection.cancel()
        }

        private func receive() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
                guard let self else { return }
                if let data {
                    lock.lock()
                    buffer.append(data)
                    lock.unlock()
                }
                if !isComplete, error == nil {
                    receive()
                }
            }
        }
    }
}
#endif
