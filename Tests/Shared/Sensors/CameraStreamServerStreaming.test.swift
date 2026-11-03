import CoreVideo
import Foundation
import Network
@testable import Shared
import SharedTesting
import Testing

/// Runs the MJPEG server on a loopback port and talks to it over raw TCP. Its settings live in the
/// shared app-group defaults, so the suite serializes with other shared-state tests.
@Suite(.sharedState)
struct CameraStreamServerStreamingTests {
    private static let keys = ["camera_stream_port", "camera_stream_frame_rate", "camera_stream_username"]

    private final class Client: @unchecked Sendable {
        private let lock = NSLock()
        private var buffer = Data()
        private(set) var closed = false
        let connection: NWConnection

        init(port: Int) {
            self.connection = NWConnection(
                host: "127.0.0.1",
                port: NWEndpoint.Port(rawValue: UInt16(port))!,
                using: .tcp
            )
            connection.start(queue: .global())
            receive()
        }

        private func receive() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, done, error in
                guard let self else { return }
                lock.lock()
                if let data { buffer.append(data) }
                if done || error != nil { closed = true }
                lock.unlock()
                if !done, error == nil { receive() }
            }
        }

        func send(_ text: String) {
            connection.send(content: Data(text.utf8), completion: .idempotent)
        }

        var text: String {
            lock.lock(); defer { lock.unlock() }
            return String(decoding: buffer, as: UTF8.self)
        }

        var isClosed: Bool {
            lock.lock(); defer { lock.unlock() }
            return closed
        }
    }

    /// Runs `body` against a fresh server with no password, then stops the server and waits for the
    /// stop to finish before restoring the settings and the keychain password the server shares with
    /// the app.
    private func withServer(_ body: (CameraStreamServer, Int) async throws -> Void) async throws {
        let prefs = Current.settingsStore.prefs
        let previous = Self.keys.map { prefs.object(forKey: $0) }
        let server = CameraStreamServer()
        // The password lives in the shared keychain, and any saved one makes the server demand credentials.
        let previousPassword = server.password
        server.password = ""
        let port = Int.random(in: 41000 ... 48000)
        server.port = port

        let outcome: Result<Void, Error>
        do {
            try #require(server.password.isEmpty)
            try await body(server, port)
            outcome = .success(())
        } catch {
            outcome = .failure(error)
        }

        await shutDown(server)
        server.password = previousPassword
        for (key, value) in zip(Self.keys, previous) {
            prefs.set(value, forKey: key)
        }
        try outcome.get()
    }

    /// Stops `server` and waits for everything the stop queues: `setActive(false)` cancels the listener
    /// and the clients on the server's queue, which then posts the camera-observer removal and the
    /// state callback to the main queue, and the removal posts its own cleanup there in turn.
    private func shutDown(_ server: CameraStreamServer) async {
        server.setActive(false)
        // `isActive` reads through the server's serial queue, so it returns only once the stop has run.
        #expect(!server.isActive)
        #expect(server.clientCount == 0)
        let observerRemoved = await drainMainQueue()
        let removalCleanedUp = await drainMainQueue()
        #expect(observerRemoved && removalCleanedUp)
        withExtendedLifetime(server) {}
    }

    /// Lets the main queue run what was put on it so far. Returns `false` if it did not get there in time.
    private func drainMainQueue() async -> Bool {
        let drained = Counter()
        DispatchQueue.main.async { drained.increment() }
        let deadline = Date().addingTimeInterval(10)
        while drained.value == 0, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(5))
        }
        return drained.value > 0
    }

    private func waitUntil(_ condition: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }

    private func frame() throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, 32, 32, kCVPixelFormatType_32BGRA, attributes, &pixelBuffer)
        let buffer = try #require(pixelBuffer)
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            memset(base, 0x80, CVPixelBufferGetDataSize(buffer))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }

    @Test func settingsHaveDefaultsAndPersist() async throws {
        try await withServer { server, port in
            #expect(server.port == port)
            Current.settingsStore.prefs.removeObject(forKey: "camera_stream_port")
            Current.settingsStore.prefs.removeObject(forKey: "camera_stream_frame_rate")
            #expect(server.port == 8090)
            #expect(server.streamFrameRate == 15)
            server.streamFrameRate = 24
            #expect(server.streamFrameRate == 24)
            server.username = "kiosk"
            #expect(server.username == "kiosk")
            if let url = server.streamURL {
                #expect(url.hasPrefix("http://"))
                #expect(url.hasSuffix(":8090/camera"))
            }
            #expect(!server.isActive)
            #expect(!server.isStreaming)
            #expect(server.clientCount == 0)
        }
    }

    @Test func streamsFramesToAnAuthorizedClient() async throws {
        try await withServer { server, port in
            server.username = ""
            let stateChanges = Counter()
            server.onStateChange = { stateChanges.increment() }
            server.setActive(true)
            server.setActive(true)
            try await waitUntil { server.isActive }

            // The request line and the headers arrive in separate segments.
            let client = Client(port: port)
            defer { client.connection.cancel() }
            client.send("GET /camera HTTP/1.1\r\n")
            try await Task.sleep(for: .milliseconds(50))
            client.send("Host: 127.0.0.1\r\n\r\n")

            try await waitUntil { client.text.hasPrefix("HTTP/1.1 200 OK") }
            try await waitUntil { server.clientCount == 1 }
            #expect(server.isStreaming)
            #expect(client.text.contains("multipart/x-mixed-replace"))

            let pixels = try frame()
            let deadline = Date().addingTimeInterval(10)
            while !client.text.contains("Content-Type: image/jpeg"), Date() < deadline {
                server.handle(frame: pixels)
                try await Task.sleep(for: .milliseconds(50))
            }
            #expect(client.text.contains("--hacameraframe"))
            #expect(client.text.contains("Content-Type: image/jpeg"))

            server.setActive(false)
            try await waitUntil { !server.isActive && server.clientCount == 0 }
            try await waitUntil { stateChanges.value >= 2 }
        }
    }

    @Test func rejectsClientsWithoutCredentials() async throws {
        try await withServer { server, port in
            server.username = "kiosk"
            server.setActive(true)
            try await waitUntil { server.isActive }

            let client = Client(port: port)
            defer { client.connection.cancel() }
            client.send("GET /camera HTTP/1.1\r\nHost: 127.0.0.1\r\nAccept: */*\r\n\r\n")

            try await waitUntil { client.text.hasPrefix("HTTP/1.1 401 Unauthorized") }
            #expect(client.text.contains("WWW-Authenticate: Basic"))
            try await waitUntil { client.isClosed }
            #expect(server.clientCount == 0)
        }
    }

    @Test func changingThePortRestartsTheListener() async throws {
        try await withServer { server, port in
            server.username = ""
            server.setActive(true)
            try await waitUntil { server.isActive }

            let newPort = port + 1
            server.port = newPort
            let deadline = Date().addingTimeInterval(10)
            var answered = false
            while !answered, Date() < deadline {
                let client = Client(port: newPort)
                client.send("GET / HTTP/1.1\r\n\r\n")
                let start = Date()
                while !client.text.hasPrefix("HTTP/1.1 200 OK"), !client.isClosed, Date().timeIntervalSince(start) < 1 {
                    try await Task.sleep(for: .milliseconds(10))
                }
                answered = client.text.hasPrefix("HTTP/1.1 200 OK")
                client.connection.cancel()
            }
            #expect(answered)
        }
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.lock(); count += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}
