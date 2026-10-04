import CoreVideo
import Network
@testable import Shared
import XCTest

#if os(iOS) && !targetEnvironment(macCatalyst)
/// Drives the MJPEG server over loopback. The simulator has no camera, so no frames flow unless a
/// test hands one in — the state a kiosk is left in once its camera service has died.
class CameraStreamServerConnectionTests: XCTestCase {
    private var server: CameraStreamServer?
    private var clients: [NWConnection] = []

    override func setUp() {
        super.setUp()
        Current.motionDetection = NoCameraMotionDetectionManager()
    }

    override func tearDown() {
        clients.forEach { $0.cancel() }
        clients.removeAll()
        if let server {
            server.setActive(false)
            // `isActive` syncs on the server's queue, so once it reads false the camera observation
            // has been handed to the main queue; let it reach this test's fake before swapping it out.
            XCTAssertFalse(server.isActive)
            let released = expectation(description: "camera observation released")
            DispatchQueue.main.async { released.fulfill() }
            wait(for: [released], timeout: 5)
        }
        server = nil
        Current.motionDetection = MotionDetectionManager()
        super.tearDown()
    }

    /// A client that closes its end only sends a FIN, and with no frames being written there is no
    /// failed send to give it away. Reading is the only way the server can tell it has gone.
    func testClientThatHangsUpIsRemovedWhileNoFramesFlow() throws {
        let port = Self.randomPort()
        let server = startServer(port: port)
        let client = try XCTUnwrap(openStream(port: port))
        XCTAssertTrue(waitUntil { server.clientCount == 1 })

        client.cancel()
        XCTAssertTrue(waitUntil { server.clientCount == 0 })
    }

    func testFrameReachesConnectedClient() throws {
        let port = Self.randomPort()
        let server = startServer(port: port)
        let client = try XCTUnwrap(openStream(port: port))
        XCTAssertTrue(waitUntil { server.clientCount == 1 })

        try server.handle(frame: makeFrame())
        XCTAssertTrue(waitForBytes(containing: "Content-Type: image/jpeg", on: client))
        XCTAssertEqual(server.clientCount, 1)
    }

    // MARK: - Helpers

    private static func randomPort() -> UInt16 {
        UInt16.random(in: 20000 ... 60000)
    }

    private func startServer(port: UInt16) -> CameraStreamServer {
        let server = LoopbackCameraStreamServer(port: Int(port))
        server.setActive(true)
        self.server = server
        return server
    }

    /// Connects and asks for the stream, retrying while the listener is still coming up.
    private func openStream(port: UInt16) -> NWConnection? {
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else { return nil }

        for _ in 0 ..< 50 {
            let connection = NWConnection(host: .ipv4(.loopback), port: endpointPort, using: .tcp)
            let settled = XCTestExpectation(description: "connection settled")
            settled.assertForOverFulfill = false
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready, .waiting, .failed:
                    settled.fulfill()
                default:
                    break
                }
            }
            connection.start(queue: .global())
            _ = XCTWaiter.wait(for: [settled], timeout: 5)

            if case .ready = connection.state {
                let request = "GET /camera HTTP/1.1\r\nHost: localhost\r\n\r\n"
                connection.send(content: Data(request.utf8), completion: .idempotent)
                clients.append(connection)
                return connection
            }
            connection.cancel()
            Thread.sleep(forTimeInterval: 0.1)
        }
        return nil
    }

    private func waitUntil(_ condition: @escaping () -> Bool) -> Bool {
        let met = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        return XCTWaiter.wait(for: [met], timeout: 10) == .completed
    }

    private func waitForBytes(containing marker: String, on connection: NWConnection) -> Bool {
        let found = XCTestExpectation(description: "received \(marker)")
        StreamReader(connection: connection, marker: Data(marker.utf8), found: found).read()
        return XCTWaiter.wait(for: [found], timeout: 10) == .completed
    }

    private func makeFrame() throws -> CVPixelBuffer {
        var frame: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, 64, 48, kCVPixelFormatType_32BGRA, nil, &frame)
        XCTAssertEqual(status, kCVReturnSuccess)
        return try XCTUnwrap(frame)
    }
}

/// Listens on the port it was made with and serves without credentials, whatever this device has
/// stored.
private final class LoopbackCameraStreamServer: CameraStreamServer {
    private let fixedPort: Int

    init(port: Int) {
        self.fixedPort = port
        super.init()
    }

    override var port: Int {
        get { fixedPort }
        set {}
    }

    override var username: String {
        get { "" }
        set {}
    }

    override var password: String {
        get { "" }
        set {}
    }
}

private final class NoCameraMotionDetectionManager: MotionDetectionManager {
    override var canDetectMotion: Bool { false }
}

/// Accumulates what a client receives until a marker turns up. Each read is only issued once the
/// previous one has completed, so the buffer is never touched from two places at once.
private final class StreamReader {
    private let connection: NWConnection
    private let marker: Data
    private let found: XCTestExpectation
    private var received = Data()

    init(connection: NWConnection, marker: Data, found: XCTestExpectation) {
        self.connection = connection
        self.marker = marker
        self.found = found
    }

    func read() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [self] data, _, isComplete, error in
            if let data {
                received.append(data)
            }
            if received.range(of: marker) != nil {
                found.fulfill()
            } else if !isComplete, error == nil {
                read()
            }
        }
    }
}
#endif
