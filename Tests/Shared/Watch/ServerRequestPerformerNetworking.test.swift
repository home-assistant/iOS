import Foundation
@testable import Shared
import Testing

/// Drives `ServerRequestPerformer` through a stubbed `URLProtocol` so the real transport — the
/// session, the continuation and the cancellation handling — is exercised without a server.
///
/// Serialized because the stub's handler is process-wide static state.
@Suite(.serialized)
struct ServerRequestPerformerNetworkingTests {
    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    /// A configuration whose requests are answered by `StubbedRequestProtocol` instead of the network.
    private func stubbedConfiguration(timeout: TimeInterval = 30) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubbedRequestProtocol.self]
        configuration.timeoutIntervalForRequest = timeout
        return configuration
    }

    private func request(_ path: String = "/api/states") -> URLRequest {
        URLRequest(url: url("https://ha.example.com\(path)"))
    }

    @Test func returnsTheBodyAndResponseOnSuccess() async throws {
        StubbedRequestProtocol.respond(statusCode: 200, body: Data(#"{"state":"on"}"#.utf8))
        defer { StubbedRequestProtocol.reset() }

        let (data, response) = try await ServerRequestPerformer.perform(
            request(),
            server: ServerFixture.standard,
            configuration: stubbedConfiguration()
        )

        #expect(response.statusCode == 200)
        #expect(data == Data(#"{"state":"on"}"#.utf8))
    }

    /// A 4xx or 5xx is a completed request, not a thrown error — callers decide what it means, which
    /// is what lets the watch see a 401 and invalidate its token rather than retrying blindly.
    @Test func returnsNonSuccessStatusesWithoutThrowing() async throws {
        StubbedRequestProtocol.respond(statusCode: 401, body: Data())
        defer { StubbedRequestProtocol.reset() }

        let (_, response) = try await ServerRequestPerformer.perform(
            request(),
            server: ServerFixture.standard,
            configuration: stubbedConfiguration()
        )

        #expect(response.statusCode == 401)
    }

    @Test func throwsWhenTheTransportFails() async {
        StubbedRequestProtocol.fail(with: URLError(.cannotConnectToHost))
        defer { StubbedRequestProtocol.reset() }

        await #expect(throws: (any Error).self) {
            try await ServerRequestPerformer.perform(
                request(),
                server: ServerFixture.standard,
                configuration: stubbedConfiguration()
            )
        }
    }

    /// Cancelling the caller has to tear the request down rather than leave the continuation
    /// suspended — the failure mode the magic-item watchdog exists to catch.
    @Test func cancellationFinishesTheRequestRatherThanHanging() async throws {
        StubbedRequestProtocol.hang()
        defer { StubbedRequestProtocol.reset() }

        let task = Task {
            try await ServerRequestPerformer.perform(
                request(),
                server: ServerFixture.standard,
                configuration: stubbedConfiguration()
            )
        }
        // Let the request reach the stub before pulling it out from under the caller.
        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()

        await #expect(throws: (any Error).self) {
            try await task.value
        }
    }

    /// A response that isn't HTTP at all carries no status for the caller to act on, so it is an
    /// error rather than a success with no status.
    @Test func throwsWhenTheResponseIsNotHTTP() async {
        StubbedRequestProtocol.respondWithoutHTTP()
        defer { StubbedRequestProtocol.reset() }

        await #expect(throws: HomeAssistantRESTError.invalidResponse) {
            try await ServerRequestPerformer.perform(
                request(),
                server: ServerFixture.standard,
                configuration: stubbedConfiguration()
            )
        }
    }

    /// The cancel-before-`adopt` race, provoked directly rather than hoped for by timing: a data
    /// task that was never resumed is not guaranteed to deliver a completion callback when
    /// cancelled, and that callback is the only thing that resumes the continuation and lets the
    /// session be invalidated.
    @Test func adoptingAfterCancellationStartsTheTaskBeforeCancellingIt() {
        StubbedRequestProtocol.hang()
        defer { StubbedRequestProtocol.reset() }

        let session = URLSession(configuration: stubbedConfiguration())
        defer { session.finishTasksAndInvalidate() }
        let task = session.dataTask(with: request())
        let box = ServerRequestPerformer.CancellableTaskBox()

        box.cancel()
        box.adopt(task)

        #expect(task.state != .suspended, "a task left suspended never reports completion")
    }

    /// The same race the other way round: the caller gives up before the data task has even been
    /// handed over. A task that is never resumed is not guaranteed to deliver a completion, so this
    /// would hang forever if `adopt` did not resume it first.
    @Test func cancellationBeforeTheRequestStartsStillFinishes() async {
        StubbedRequestProtocol.hang()
        defer { StubbedRequestProtocol.reset() }

        let task = Task {
            try await ServerRequestPerformer.perform(
                request(),
                server: ServerFixture.standard,
                configuration: stubbedConfiguration()
            )
        }
        task.cancel()

        await #expect(throws: (any Error).self) {
            try await task.value
        }
    }
}

/// Answers requests from the test instead of the network. Named distinctly from the app target's
/// own stub so the two can coexist in one test bundle.
final class StubbedRequestProtocol: URLProtocol {
    private enum Behavior {
        case respond(statusCode: Int, body: Data)
        case fail(any Error)
        /// Never answers, so the test can cancel a request that is genuinely in flight.
        case hang
        /// Answers with a plain `URLResponse`, which carries no status code.
        case nonHTTP
    }

    private static let lock = NSLock()
    private static var behavior: Behavior = .respond(statusCode: 200, body: Data())

    static func respond(statusCode: Int, body: Data) {
        lock.lock()
        defer { lock.unlock() }
        behavior = .respond(statusCode: statusCode, body: body)
    }

    static func fail(with error: any Error) {
        lock.lock()
        defer { lock.unlock() }
        behavior = .fail(error)
    }

    static func hang() {
        lock.lock()
        defer { lock.unlock() }
        behavior = .hang
    }

    static func respondWithoutHTTP() {
        lock.lock()
        defer { lock.unlock() }
        behavior = .nonHTTP
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        behavior = .respond(statusCode: 200, body: Data())
    }

    private static var currentBehavior: Behavior {
        lock.lock()
        defer { lock.unlock() }
        return behavior
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let client else { return }

        switch Self.currentBehavior {
        case let .respond(statusCode, body):
            guard let url = request.url,
                  let response = HTTPURLResponse(
                      url: url,
                      statusCode: statusCode,
                      httpVersion: nil,
                      headerFields: nil
                  ) else {
                client.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: body)
            client.urlProtocolDidFinishLoading(self)
        case let .fail(error):
            client.urlProtocol(self, didFailWithError: error)
        case .nonHTTP:
            guard let url = request.url else {
                client.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }
            let response = URLResponse(
                url: url,
                mimeType: "text/plain",
                expectedContentLength: 0,
                textEncodingName: nil
            )
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocolDidFinishLoading(self)
        case .hang:
            break
        }
    }

    override func stopLoading() {}
}
