@testable import HomeAssistant
import Network
import PromiseKit
@testable import Shared
import Testing

/// The onboarding pre-step that spots a server asking for a client certificate. It is pointed at a
/// listener on the loopback interface that answers the way such a server, or a plain one, would.
@MainActor
struct OnboardingAuthStepClientCertificateTests {
    /// Answers every request with `response`, then closes the connection.
    private final class LoopbackServer {
        private let listener: NWListener
        private let queue = DispatchQueue(label: "client-certificate-step-tests.listener")

        init(response: String) throws {
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
            self.listener = try NWListener(using: parameters)
            listener.newConnectionHandler = { [queue] connection in
                connection.start(queue: queue)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { _, _, _, _ in
                    connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                }
            }
            listener.start(queue: queue)
        }

        func waitForPort() async -> UInt16? {
            var port: UInt16?
            _ = await LoadTolerantDeadline.waitUntil {
                if case .ready = listener.state {
                    port = listener.port?.rawValue
                }
                return port != nil
            }
            return port
        }

        func stop() {
            listener.cancel()
        }
    }

    private static func httpResponse(status: String, body: String) -> String {
        "HTTP/1.1 \(status)\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
    }

    private enum Outcome: Equatable {
        case fulfilled
        case rejected
    }

    private func settle(_ promise: Promise<some Any>) async -> Outcome {
        await withCheckedContinuation { continuation in
            promise.pipe { result in
                switch result {
                case .fulfilled:
                    continuation.resume(returning: .fulfilled)
                case .rejected:
                    continuation.resume(returning: .rejected)
                }
            }
        }
    }

    private func value(_ promise: Promise<Bool>) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            promise.pipe { result in
                switch result {
                case let .fulfilled(value):
                    continuation.resume(returning: value)
                case let .rejected(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// What these tests wait for lands through the main queue, which other suites keep busy under
    /// load, so the deadline counts main-queue turns as well as time.
    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        await LoadTolerantDeadline.waitUntil(condition)
    }

    private func withServer(
        responding response: String,
        _ body: (URL) async throws -> Void
    ) async throws {
        let server = try LoopbackServer(response: response)
        defer { server.stop() }
        let portValue = await server.waitForPort()
        let port = try #require(portValue)
        try await body(#require(URL(string: "http://127.0.0.1:\(port)/auth/authorize?x=1")))
    }

    @Test(arguments: [
        (status: "400 Bad Request", body: "No required SSL certificate was sent", requires: true),
        (status: "400 Bad Request", body: "Bad request", requires: false),
        (status: "200 OK", body: "<html></html>", requires: false),
    ])
    func detectsAServerThatAsksForACertificate(status: String, body: String, requires: Bool) async throws {
        try await withServer(responding: Self.httpResponse(status: status, body: body)) { url in
            let result = try await value(OnboardingAuthStepClientCertificate.requiresClientCertificate(at: url))
            #expect(result == requires)
        }
    }

    @Test func anUnreachableServerDoesNotAskForACertificate() async throws {
        let url = try #require(URL(string: "http://127.0.0.1:9"))
        let expectation1 = try await value(OnboardingAuthStepClientCertificate.requiresClientCertificate(at: url)) ==
            false
        #expect(expectation1)
    }

    @Test func aPlainServerLetsTheFlowContinue() async throws {
        try await withServer(responding: Self.httpResponse(status: "200 OK", body: "")) { url in
            let presenter = OnboardingAuthPresenter()
            let step = try OnboardingAuthStepClientCertificate(
                authDetails: OnboardingAuthDetails(baseURL: url),
                presenter: presenter
            )

            let expectation2 = await settle(step.perform(point: .beforeAuth)) == .fulfilled
            #expect(expectation2)
            #expect(presenter.clientCertificateRequest == nil)
            #expect(OnboardingAuthStepClientCertificate.supportedPoints == [.beforeAuth])
        }
    }

    @Test(arguments: [true, false])
    func aServerAskingForACertificatePromptsForOne(imports: Bool) async throws {
        let response = Self.httpResponse(status: "400 Bad Request", body: "No required SSL certificate was sent")
        try await withServer(responding: response) { url in
            let presenter = OnboardingAuthPresenter()
            let details = try OnboardingAuthDetails(baseURL: url)
            let step = OnboardingAuthStepClientCertificate(authDetails: details, presenter: presenter)

            let promise = step.perform(point: .beforeAuth)
            let expectation3 = await waitUntil { presenter.clientCertificateRequest != nil }
            #expect(expectation3)
            let request = try #require(presenter.clientCertificateRequest)

            if imports {
                request.complete(with: ClientCertificate(keychainIdentifier: "test-identity", displayName: "Test"))
                let expectation4 = await settle(promise) == .fulfilled
                #expect(expectation4)
                #expect(details.clientCertificate?.displayName == "Test")
            } else {
                request.cancel()
                let expectation5 = await settle(promise) == .rejected
                #expect(expectation5)
            }
            #expect(presenter.clientCertificateRequest == nil)
        }
    }
}
