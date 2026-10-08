import Alamofire
import Foundation
import OHHTTPStubs
import OHHTTPStubsSwift
import PromiseKit
@testable import Shared
import XCTest

/// Home Assistant decorates `/auth/token` with `log_invalid_auth`, so every refusal it answers is a
/// `Login attempt or request with invalid authentication` warning and raises the "Login attempt failed"
/// notification on the user's instance. Once the server has refused a refresh token, only a new login
/// replaces it, so every retry is a guaranteed failure that the user gets to read about.
class TokenManagerRefreshTokenRejectionTests: XCTestCase {
    private var stubDescriptor: HTTPStubsDescriptor?
    private var previousReauthenticationHandler: ((Server, Int, String) -> Void)!

    private let recorder = RequestRecorder()

    override func setUp() {
        super.setUp()
        previousReauthenticationHandler = HANetworkingEnvironment.current.handleReauthenticationRequired
        HANetworkingEnvironment.current.handleReauthenticationRequired = { [recorder] _, _, _ in
            recorder.recordReauthentication()
        }
    }

    override func tearDown() {
        HANetworkingEnvironment.current.handleReauthenticationRequired = previousReauthenticationHandler
        if let stubDescriptor {
            HTTPStubs.removeStub(stubDescriptor)
        }
        stubDescriptor = nil
        super.tearDown()
    }

    /// The incident this guards against: one revoked session turned into sixteen refusals in
    /// twenty-two seconds, because the websocket reconnect, the web view's `getExternalAuth` and the
    /// bearer-token path each drove their own refresh while the re-authentication prompt waited for the
    /// user. Only the first one can be known to be worth sending.
    func testServerIsAskedOnlyOnceWhateverDrivesTheRefresh() async {
        stubRefreshToken(.rejection)
        let server = Self.serverWithExpiredToken()
        let tokenManager = TokenManager(server: server)

        await assertRefused(tokenManager.authDictionaryForWebView(forceRefresh: true))
        XCTAssertEqual(recorder.requestCount, 1)

        // Every other way into a refresh, after the server has already had its say.
        await assertRefused(tokenManager.bearerToken)
        await assertRefused(tokenManager.authDictionaryForWebView(forceRefresh: false))
        await assertRefused(tokenManager.authDictionaryForWebView(forceRefresh: true))
        await assertRefused(tokenManager.bearerToken)

        XCTAssertEqual(recorder.requestCount, 1)
    }

    /// The refusal has to read as "log in again" rather than as a transport failure, or a caller
    /// retries it as if the network had hiccuped.
    func testRefusedRefreshReportsThatReauthenticationIsRequired() async {
        stubRefreshToken(.rejection)
        let server = Self.serverWithExpiredToken()
        let tokenManager = TokenManager(server: server)

        _ = await settle(tokenManager.bearerToken)

        let error = await assertRefused(tokenManager.bearerToken)
        XCTAssertEqual(error as? TokenManager.TokenError, .reauthenticationRequired)
        // Whatever surfaces the error tells the user to log in, rather than naming a token.
        XCTAssertEqual(error?.localizedDescription, L10n.TokenError.reauthenticationRequired)
    }

    /// The prompt is what the user acts on, so it must be raised by the server's answer and not by each
    /// caller that happens to ask afterwards.
    func testReauthenticationIsRequestedOncePerRejection() async {
        stubRefreshToken(.rejection)
        let server = Self.serverWithExpiredToken()
        let tokenManager = TokenManager(server: server)

        for _ in 0 ..< 5 {
            _ = await settle(tokenManager.bearerToken)
        }

        XCTAssertEqual(recorder.reauthenticationCount, 1)
    }

    /// A refresh that fails because the server was unreachable or broke recovers on its own, so it must
    /// stay retriable: latching it would strand a working installation behind a login prompt.
    func testTransientFailureIsRetried() async {
        stubRefreshToken(.serverError)
        let server = Self.serverWithExpiredToken()
        let tokenManager = TokenManager(server: server)

        _ = await settle(tokenManager.bearerToken)
        _ = await settle(tokenManager.bearerToken)

        XCTAssertEqual(recorder.requestCount, 2)
        XCTAssertEqual(recorder.reauthenticationCount, 0)
    }

    /// Logging back in stores a token minted from a fresh authorization code, which is what lifts the
    /// refusal — the manager outlives re-authentication, so nothing else would.
    func testLoggingInAgainLetsTheNewTokenThrough() async throws {
        stubRefreshToken(.rejection)
        let server = Self.serverWithExpiredToken()
        let tokenManager = TokenManager(server: server)

        _ = await settle(tokenManager.bearerToken)
        XCTAssertEqual(recorder.requestCount, 1)

        // What `WebViewController.applyNewToken` writes once the user finishes logging in.
        stubRefreshToken(.success)
        server.update { info in
            info.token = .init(
                accessToken: "ReauthenticatedAccessToken",
                refreshToken: "ReauthenticatedRefreshToken",
                expiration: Current.date().addingTimeInterval(-10)
            )
        }

        let token = try await settle(tokenManager.bearerToken).get()
        XCTAssertEqual(token.0, "RefreshedAccessToken")
        XCTAssertEqual(recorder.requestCount, 2)
        XCTAssertEqual(recorder.lastSentRefreshToken, "ReauthenticatedRefreshToken")
    }

    /// Logging out revokes the refresh token along with the access token, so refreshing is as dead as
    /// re-sending the access token — and the app keeps running until the user signs back in.
    func testRevokedRefreshTokenIsNeverSent() async {
        stubRefreshToken(.rejection)
        let server = Server.fake()
        let tokenManager = TokenManager(server: server)

        tokenManager.handleTokenRevoked()
        _ = await settle(tokenManager.bearerToken)
        _ = await settle(tokenManager.authDictionaryForWebView(forceRefresh: true))

        XCTAssertEqual(recorder.requestCount, 0)
    }

    /// A server recovered from the GRDB mirror carries `ServerInfo.mirrorPlaceholderToken`: empty
    /// strings, deliberately, because the mirror holds no credentials. Sending those is asking the
    /// server to log an invalid authentication for a token that was never real.
    func testPlaceholderCredentialsFromAMirrorRestoreAreNeverSent() async {
        stubRefreshToken(.rejection)
        let server = Server.fake(update: { $0.token = ServerInfo.mirrorPlaceholderToken })
        let tokenManager = TokenManager(server: server)

        XCTAssertTrue(server.info.requiresReauthenticationAfterMirrorRestore)

        _ = await settle(tokenManager.bearerToken)
        _ = await settle(tokenManager.authDictionaryForWebView(forceRefresh: true))

        XCTAssertEqual(recorder.requestCount, 0)
    }

    /// The Alamofire interceptor signs from the store, so a placeholder would otherwise go out as a
    /// bare `Bearer ` on every request the session makes. Failing the request is the only honest
    /// outcome while there is nothing to sign it with.
    func testInterceptorDoesNotSignWithPlaceholderCredentials() throws {
        stubRefreshToken(.rejection)
        let url = try XCTUnwrap(URL(string: "http://homeassistant.local:8123/api/"))
        let server = Server.fake(update: { $0.token = ServerInfo.mirrorPlaceholderToken })
        let tokenManager = TokenManager(server: server)
        let interceptor = tokenManager.authenticationInterceptor

        var adaptation: Swift.Result<URLRequest, Error>?
        let adapted = expectation(description: "request adapted")
        interceptor.adapt(URLRequest(url: url), for: Session.default) { result in
            adaptation = result
            adapted.fulfill()
        }
        wait(for: [adapted], timeout: 10)

        let outcome = try XCTUnwrap(adaptation)
        if let request = try? outcome.get() {
            XCTFail("signed a request with \(request.value(forHTTPHeaderField: "Authorization") ?? "no header")")
        }
        XCTAssertEqual(recorder.requestCount, 0)
    }

    // MARK: - Helpers

    private static func serverWithExpiredToken() -> Server {
        Server.fake(update: { info in
            info.token = .init(
                accessToken: "FakeAccessToken",
                refreshToken: "FakeRefreshToken",
                // Already lapsed, so the bearer path goes through a refresh rather than handing the
                // stored token straight back.
                expiration: Current.date().addingTimeInterval(-10)
            )
        })
    }

    private enum RefreshOutcome {
        /// What Home Assistant answers for a refresh token it no longer has.
        case rejection
        case serverError
        case success
    }

    private func stubRefreshToken(_ outcome: RefreshOutcome) {
        if let stubDescriptor {
            HTTPStubs.removeStub(stubDescriptor)
        }

        stubDescriptor = stub(condition: { $0.url?.path == "/auth/token" }, response: { [recorder] request in
            recorder.recordRequest(body: request.ohhttpStubs_httpBody)

            switch outcome {
            case .rejection:
                return HTTPStubsResponse(
                    jsonObject: ["error": "invalid_grant"],
                    statusCode: 400,
                    headers: nil
                )
            case .serverError:
                return HTTPStubsResponse(
                    jsonObject: ["error": "internal_error"],
                    statusCode: 500,
                    headers: nil
                )
            case .success:
                return HTTPStubsResponse(
                    jsonObject: ["access_token": "RefreshedAccessToken", "expires_in": 1800],
                    statusCode: 200,
                    headers: nil
                )
            }
        })
    }

    /// The outcome of a promise, so a test can assert on a refusal rather than only on a success.
    private func settle<T>(_ promise: Promise<T>) async -> Swift.Result<T, Error> {
        do {
            let value = try await promise.asyncValue(timeout: 10)
            return .success(value)
        } catch {
            return .failure(error)
        }
    }

    /// Fails unless the promise refuses, and hands the error back for a test that cares which one.
    @discardableResult
    private func assertRefused(
        _ promise: Promise<some Any>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> Error? {
        switch await settle(promise) {
        case let .success(value):
            XCTFail("expected a refusal, got \(value)", file: file, line: line)
            return nil
        case let .failure(error):
            return error
        }
    }

    /// Stub responses are delivered off the main queue, so the counts they feed are guarded.
    private final class RequestRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var requests: [Data?] = []
        private var reauthentications = 0

        var requestCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return requests.count
        }

        var reauthenticationCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return reauthentications
        }

        /// The `refresh_token` form field of the most recent request, which is the token that actually
        /// reached the server.
        var lastSentRefreshToken: String? {
            lock.lock()
            defer { lock.unlock() }
            guard let body = requests.last ?? nil, let form = String(data: body, encoding: .utf8) else {
                return nil
            }
            return URLComponents(string: "?\(form)")?.queryItems?.first { $0.name == "refresh_token" }?.value
        }

        func recordRequest(body: Data?) {
            lock.lock()
            defer { lock.unlock() }
            requests.append(body)
        }

        func recordReauthentication() {
            lock.lock()
            defer { lock.unlock() }
            reauthentications += 1
        }
    }
}
