@testable import HomeAssistant
import Network
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// The connection diagnostics run from the connection error screen, driven against a listener on
/// the loopback interface so every check resolves without leaving the device.
@MainActor
struct ConnectivityCheckerTests {
    /// A TCP listener on 127.0.0.1 that answers every request with an empty `200 OK`.
    private final class LoopbackHTTPServer {
        private let listener: NWListener
        private let queue = DispatchQueue(label: "connectivity-checker-tests.listener")

        init() throws {
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
            self.listener = try NWListener(using: parameters)
            listener.newConnectionHandler = { [queue] connection in
                connection.start(queue: queue)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, _ in
                    guard data != nil else {
                        connection.cancel()
                        return
                    }
                    let response = Data("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8)
                    connection.send(content: response, completion: .contentProcessed { _ in
                        connection.cancel()
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
        }
    }

    private func result(_ state: ConnectivityCheckState, _ type: ConnectivityCheckType) -> ConnectivityCheckResult? {
        state.checks.first { $0.type == type }?.result
    }

    private func isSuccess(_ result: ConnectivityCheckResult?) -> Bool {
        if case .success = result { return true }
        return false
    }

    private func isFailure(_ result: ConnectivityCheckResult?) -> Bool {
        if case .failure = result { return true }
        return false
    }

    // MARK: - State

    @Test func everyCheckStartsPendingAndCanBeResetAfterAnUpdate() {
        let state = ConnectivityCheckState()
        #expect(state.checks.map(\.type) == ConnectivityCheckType.allCases)
        #expect(state.checks.allSatisfy { $0.result == .pending })

        state.updateCheck(type: .port, result: .failure(error: "refused"))
        state.isRunning = true
        #expect(result(state, .port) == .failure(error: "refused"))

        state.reset()
        #expect(state.checks.allSatisfy { $0.result == .pending })
        #expect(!state.isRunning)
    }

    @Test func onlyFinishedResultsCountAsCompleted() {
        #expect(!ConnectivityCheckResult.pending.isCompleted)
        #expect(!ConnectivityCheckResult.running.isCompleted)
        #expect(ConnectivityCheckResult.success(message: nil).isCompleted)
        #expect(ConnectivityCheckResult.failure(error: "x").isCompleted)
        #expect(ConnectivityCheckResult.skipped.isCompleted)
    }

    @Test func everyCheckHasALocalizedName() {
        let names = ConnectivityCheckType.allCases.map(\.localizedName)
        #expect(names.allSatisfy { !$0.isEmpty })
        #expect(Set(names).count == names.count)
    }

    // MARK: - Running the checks

    @Test func aURLWithoutAHostFailsEveryCheck() async throws {
        let state = ConnectivityCheckState()
        let checker = ConnectivityChecker(state: state)

        try await checker.runChecks(for: #require(URL(string: "file:///tmp")))

        #expect(state.checks.allSatisfy { $0.result == .failure(error: "Invalid URL: no host found") })
        #expect(!state.isRunning)
    }

    @Test func aClosedPortSkipsTheChecksThatDependOnIt() async throws {
        // Grab a free port, then close it again so nothing is listening there.
        let server = try LoopbackHTTPServer()
        let portValue = await server.waitForPort()
        let port = try #require(portValue)
        server.stop()

        let state = ConnectivityCheckState()
        try await ConnectivityChecker(state: state).runChecks(for: #require(URL(string: "http://127.0.0.1:\(port)")))

        #expect(isSuccess(result(state, .dns)))
        #expect(isFailure(result(state, .port)))
        #expect(result(state, .tls) == .skipped)
        #expect(result(state, .server) == .skipped)
    }

    @Test func aReachableHTTPServerPassesWithoutATLSCheck() async throws {
        let server = try LoopbackHTTPServer()
        defer { server.stop() }
        let portValue = await server.waitForPort()
        let port = try #require(portValue)

        let state = ConnectivityCheckState()
        try await ConnectivityChecker(state: state).runChecks(for: #require(URL(string: "http://127.0.0.1:\(port)")))

        #expect(isSuccess(result(state, .dns)))
        #expect(result(state, .port) == .success(message: "Port \(port) is reachable"))
        #expect(result(state, .tls) == .skipped)
        #expect(result(state, .server) == .success(message: "Server responded with status 200"))
        #expect(!state.isRunning)
    }

    @Test func aPlainServerBehindAnHTTPSURLFailsTheTLSCheck() async throws {
        let server = try LoopbackHTTPServer()
        defer { server.stop() }
        let portValue = await server.waitForPort()
        let port = try #require(portValue)

        let state = ConnectivityCheckState()
        try await ConnectivityChecker(state: state).runChecks(for: #require(URL(string: "https://127.0.0.1:\(port)")))

        #expect(result(state, .port) == .success(message: "Port \(port) is reachable"))
        #expect(isFailure(result(state, .tls)))
        #expect(isFailure(result(state, .server)))
    }

    // MARK: - Rendering

    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 900))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.isHidden = true
        window.rootViewController = nil
    }

    @Test func rendersThePendingStateWithAStartButton() throws {
        try render(ConnectivityCheckView(
            state: ConnectivityCheckState(),
            url: #require(URL(string: "https://example.com")),
            onRunChecks: {}
        ))
    }

    @Test func rendersEveryCheckResult() throws {
        let state = ConnectivityCheckState()
        state.updateCheck(type: .dns, result: .success(message: "Resolved to: 127.0.0.1"))
        state.updateCheck(type: .port, result: .running)
        state.updateCheck(type: .tls, result: .failure(error: "Bad certificate"))
        state.updateCheck(type: .server, result: .skipped)
        state.isRunning = true
        try render(ConnectivityCheckView(
            state: state,
            url: #require(URL(string: "https://example.com")),
            onRunChecks: {}
        ))

        state.updateCheck(type: .port, result: .success(message: nil))
        state.isRunning = false
        try render(ConnectivityCheckView(
            state: state,
            url: #require(URL(string: "https://example.com")),
            onRunChecks: {}
        ))
    }
}
