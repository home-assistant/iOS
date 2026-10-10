import Foundation
import Network
import PromiseKit
@testable import Shared

/// A loopback HTTP server that answers every request with an empty `200` and records the `Cookie`
/// header each request carried, so a test can check what actually went out on the wire.
///
/// A real listener is needed here, not an OHHTTPStubs stub. AVFoundation loads media outside the
/// app's process, where no `URLProtocol` sees the request, and URLSession adds the cookies from
/// `httpCookieStorage` in its own HTTP handler, which a `URLProtocol` stub replaces.
final class CookieRecordingServer {
    private let listener: NWListener
    /// Every piece of state below is touched on this queue only.
    private let queue = DispatchQueue(label: "CookieRecordingServer")
    private var recorded: [String] = []
    private var waiters: [(cookie: String, resolver: Resolver<Void>)] = []

    /// Puts a cookie for a new server in `HANetworkingEnvironment.current.cookieStorage`, starts `send`
    /// with the server's URL, and throws unless a request that `send` makes carries that cookie.
    ///
    /// The cookie arrives with the request, before any response, so `send` runs in a task of its own
    /// and a client that never finishes with the empty response cannot hang the test.
    static func expectMirroredCookie(
        path: String = "",
        send: @escaping (URL) async throws -> Void
    ) async throws {
        let server = try CookieRecordingServer()
        let url = try await server.start().appendingPathComponent(path)

        // Tests run in parallel against the one shared storage, so each cookie needs its own name.
        let name = "test_\(UUID().uuidString.prefix(8))"
        guard let cookie = HTTPCookie(properties: [
            .domain: "127.0.0.1", .path: "/", .name: name, .value: "1",
        ]) else {
            throw URLError(.badURL)
        }
        HANetworkingEnvironment.current.cookieStorage.setCookie(cookie)
        defer { HANetworkingEnvironment.current.cookieStorage.deleteCookie(cookie) }

        let sending = Task { try await send(url) }
        defer { sending.cancel() }
        try await server.waitForCookie("\(name)=1")
    }

    private init() throws {
        self.listener = try NWListener(using: .tcp, on: .any)
    }

    deinit {
        listener.cancel()
    }

    private func start() async throws -> URL {
        let (ready, resolver) = Promise<Void>.pending()
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready: resolver.fulfill(())
            case let .failed(error): resolver.reject(error)
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.answer(connection)
        }
        listener.start(queue: queue)

        try await ready.asyncValue(timeout: 5)
        return URL(string: "http://127.0.0.1:\(listener.port!.rawValue)")!
    }

    /// Waits for a request whose `Cookie` header contains `cookie`, and throws if none arrives.
    private func waitForCookie(_ cookie: String) async throws {
        let (arrived, resolver) = Promise<Void>.pending()
        queue.async { [self] in
            if recorded.contains(where: { $0.contains(cookie) }) {
                resolver.fulfill(())
            } else {
                waiters.append((cookie, resolver))
            }
        }
        try await arrived.asyncValue(timeout: 5)
    }

    private func answer(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
            // A connection closed without a request, such as a port probe, has nothing to record.
            guard let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            self?.record(request)

            let response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func record(_ request: String) {
        guard let line = request.components(separatedBy: "\r\n").first(where: {
            $0.lowercased().hasPrefix("cookie:")
        }) else { return }

        let header = line.dropFirst("cookie:".count).trimmingCharacters(in: .whitespaces)
        recorded.append(header)
        for waiter in waiters where header.contains(waiter.cookie) {
            waiter.resolver.fulfill(())
        }
    }
}
