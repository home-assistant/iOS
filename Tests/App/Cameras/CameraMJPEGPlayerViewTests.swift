@testable import HomeAssistant
import Network
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// The MJPEG camera player, streaming from a listener on the loopback interface: it shows the first
/// frame it receives, and swaps the stream for an error message when the server refuses it or when
/// there is no server address to stream from.
@Suite(.sharedState)
@MainActor
struct CameraMJPEGPlayerViewTests {
    /// Answers every connection with `response`, then closes it, or with `keepsConnectionsOpen` leaves it
    /// open (as a live camera stream would be) until `stop()`.
    private final class LoopbackServer {
        private let listener: NWListener
        private let queue = DispatchQueue(label: "camera-mjpeg-tests.listener")
        private let lock = NSLock()
        private var _connections = 0
        private var openConnections: [NWConnection] = []
        var connections: Int {
            lock.lock()
            defer { lock.unlock() }
            return _connections
        }

        init(response: Data, keepsConnectionsOpen: Bool = false) throws {
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
            self.listener = try NWListener(using: parameters)
            listener.newConnectionHandler = { [weak self, queue] connection in
                if let self {
                    lock.lock()
                    _connections += 1
                    if keepsConnectionsOpen {
                        openConnections.append(connection)
                    }
                    lock.unlock()
                }
                connection.start(queue: queue)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { _, _, _, _ in
                    connection.send(content: response, completion: .contentProcessed { _ in
                        if !keepsConnectionsOpen {
                            connection.cancel()
                        }
                    })
                }
            }
            listener.start(queue: queue)
        }

        func waitForPort() async -> UInt16? {
            let deadline = Date().addingTimeInterval(10)
            while Date() < deadline {
                if case .ready = listener.state, let port = listener.port?.rawValue {
                    return port
                }
                try? await Task.sleep(for: .milliseconds(10))
            }
            return nil
        }

        func stop() {
            listener.cancel()
            lock.lock()
            let connections = openConnections
            openConnections = []
            lock.unlock()
            connections.forEach { $0.cancel() }
        }
    }

    /// Two frames of a stream that has not ended: no closing boundary follows them.
    private static func mjpegResponse() -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let jpeg = image.jpegData(compressionQuality: 0.8) ?? Data()
        var data = Data(
            "HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace; boundary=frame\r\nConnection: close\r\n\r\n"
                .utf8
        )
        for _ in 0 ..< 2 {
            data.append(Data("--frame\r\nContent-Type: image/jpeg\r\nContent-Length: \(jpeg.count)\r\n\r\n".utf8))
            data.append(jpeg)
            data.append(Data("\r\n".utf8))
        }
        return data
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private func allViews(in view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(allViews(in:))
    }

    private func hasStreamController(_ controller: UIViewController) -> Bool {
        controller.children.contains { child in
            String(describing: type(of: child)).contains("MJPEGStreamViewController") || hasStreamController(child)
        }
    }

    private func server(port: UInt16?) -> Server {
        Server.fake { info in
            info.connection.set(address: nil, for: .external)
            if let port {
                info.connection.set(address: URL(string: "http://127.0.0.1:\(port)"), for: .internal)
                info.connection.internalSSIDs = nil
                info.connection.set(address: URL(string: "http://127.0.0.1:\(port)"), for: .external)
            }
        }
    }

    private func host(_ server: Server, controlsVisible: Binding<Bool>? = nil) -> (UIViewController, UIWindow) {
        let controller = UIHostingController(rootView: CameraMJPEGPlayerView(
            server: server,
            cameraEntityId: "camera.porch",
            cameraName: "Porch",
            controlsVisible: controlsVisible
        ))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()
        return (controller, window)
    }

    private func withCleanAPICache(_ body: () async throws -> Void) async rethrows {
        let previousCachedApis = Current.cachedApis
        defer { Current.cachedApis = previousCachedApis }
        try await body()
    }

    @Test func rendersWithoutAServerAddressToStreamFrom() async {
        await withCleanAPICache {
            let (controller, window) = host(server(port: nil))
            defer {
                window.isHidden = true
                window.rootViewController = nil
            }

            for _ in 0 ..< 5 {
                await Task.yield()
            }
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }
    }

    @Test func aRefusedStreamIsRequestedFromTheServer() async throws {
        try await withCleanAPICache {
            let loopback = try LoopbackServer(
                response: Data(
                    "HTTP/1.1 500 Internal Server Error\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                        .utf8
                )
            )
            defer { loopback.stop() }
            let portValue = await loopback.waitForPort()
            let port = try #require(portValue)
            let (controller, window) = host(server(port: port))
            defer {
                window.isHidden = true
                window.rootViewController = nil
            }

            // The player asked for the stream; the refusal then swaps it for the error message.
            let expectation1 = await waitUntil { loopback.connections > 0 }
            #expect(expectation1)
            for _ in 0 ..< 10 {
                await Task.yield()
            }
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }
    }

    @Test func aStreamedFrameIsShown() async throws {
        try await withCleanAPICache {
            // The connection stays open, so the stream never ends (or errors) before its frame is checked.
            let loopback = try LoopbackServer(response: Self.mjpegResponse(), keepsConnectionsOpen: true)
            defer { loopback.stop() }
            let portValue = await loopback.waitForPort()
            let port = try #require(portValue)
            var controlsVisible = false
            let (controller, window) = host(
                server(port: port),
                controlsVisible: Binding(get: { controlsVisible }, set: { controlsVisible = $0 })
            )
            defer {
                window.isHidden = true
                window.rootViewController = nil
            }

            // A decoded frame is on screen; the error message (which replaces the stream) does not count.
            let frameShown = await waitUntil {
                allViews(in: controller.view).contains { ($0 as? UIImageView)?.image != nil }
            }
            #expect(frameShown)
            #expect(hasStreamController(controller))
            controller.view.layoutIfNeeded()
        }
    }
}
