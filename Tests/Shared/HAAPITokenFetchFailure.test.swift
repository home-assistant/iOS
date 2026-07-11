import Alamofire
import HAKit
import HAKit_Mocks
import PromiseKit
@testable import Shared
@testable import HANetworking
import XCTest

class AuthenticationAPIActiveURLTests: XCTestCase {
    /// Websocket auth waits on token refresh, so token refresh must never depend on the async
    /// network-info path: here that path hangs outright, and the refresh must still settle.
    func testRefreshTokenSettlesEvenWhenNetworkInfoRefreshHangs() {
        let previousRefreshNetworkInformation = Current.connectivity.refreshNetworkInformation
        defer { Current.connectivity.refreshNetworkInformation = previousRefreshNetworkInformation }
        Current.connectivity.refreshNetworkInformation = {
            try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
        }

        let server = Server.fake(update: { info in
            info.connection.set(address: nil, for: .external)
        })
        let api = AuthenticationAPI(server: server)

        let rejected = expectation(description: "refresh rejected without an active URL")
        api.refreshTokenWith(tokenInfo: server.info.token).catch { error in
            XCTAssertTrue(error is ServerConnectionError)
            rejected.fulfill()
        }

        wait(for: [rejected], timeout: 1)
    }
}

class HAAPITokenFetchFailureTests: XCTestCase {
    private func drainMainQueue(cycles: Int = 2) {
        let expectation = expectation(description: "drain main queue")

        func schedule(_ remaining: Int) {
            DispatchQueue.main.async {
                if remaining == 0 {
                    expectation.fulfill()
                } else {
                    schedule(remaining - 1)
                }
            }
        }

        schedule(cycles)
        wait(for: [expectation], timeout: 10.0)
    }

    func testTokenFetchFailureMarksRevokedCredentialsAsPermanent() {
        let error = AFError.responseValidationFailed(reason: .customValidationFailed(
            error: AuthenticationAPI.AuthenticationError.serverError(
                statusCode: 400,
                errorCode: "invalid_grant",
                error: nil
            )
        ))

        let failure = HomeAssistantAPI.tokenFetchFailure(from: error)

        XCTAssertTrue(failure.shouldDisconnectPermanently)
        XCTAssertTrue(failure.errorDescription?.contains("invalid_grant") == true)
    }

    func testTokenFetchFailureLeavesTransientErrorsRetryable() {
        let failure = HomeAssistantAPI.tokenFetchFailure(from: URLError(.notConnectedToInternet))

        XCTAssertFalse(failure.shouldDisconnectPermanently)
    }

    func testConnectionDelegateStopsReconnectLoopForPermanentTokenFetchFailure() {
        let api = HomeAssistantAPI(server: .fake())
        let connection = HAMockConnection()
        connection.delegate = api
        api.connection = connection

        connection.setState(.disconnected(reason: .waitingToReconnect(
            lastError: HomeAssistantAPI.TokenFetchFailure(
                underlyingType: "fatal",
                shouldDisconnectPermanently: true
            ),
            atLatest: Date(),
            retryCount: 1
        )), waitForQueue: false)

        drainMainQueue()

        XCTAssertEqual(connection.state, .disconnected(reason: .disconnected))
    }

    func testConnectionDelegateKeepsRetryingForNonPermanentTokenFetchFailure() {
        let api = HomeAssistantAPI(server: .fake())
        let connection = HAMockConnection()
        connection.delegate = api
        api.connection = connection

        let expectedState = HAConnectionState.disconnected(reason: .waitingToReconnect(
            lastError: HomeAssistantAPI.TokenFetchFailure(
                underlyingType: "transient",
                shouldDisconnectPermanently: false
            ),
            atLatest: Date(),
            retryCount: 1
        ))

        connection.setState(expectedState, waitForQueue: false)

        drainMainQueue()

        XCTAssertEqual(connection.state, expectedState)
    }

    func testConnectionDelegateRecoversFromRejectedStateWhenReconnectSucceeds() {
        let priorDelays = HomeAssistantAPI.rejectedReconnectDelays
        HomeAssistantAPI.rejectedReconnectDelays = [0, 0, 0]
        defer { HomeAssistantAPI.rejectedReconnectDelays = priorDelays }

        let api = HomeAssistantAPI(server: .fake())
        let connection = HAMockConnection()
        connection.delegate = api
        api.connection = connection

        connection.setState(.disconnected(reason: .rejected), waitForQueue: false)
        drainMainQueue(cycles: 10)

        // HAKit won't auto-reconnect a rejected connection, but our delegate explicitly retries; the
        // mock's connect() succeeds, so the rejection is recovered instead of dead-ending the socket.
        XCTAssertEqual(connection.state, .ready(version: "1.0-mock"))
    }

    func testConnectionDelegateGivesUpAfterExhaustingRejectedReconnectBudget() {
        let priorDelays = HomeAssistantAPI.rejectedReconnectDelays
        HomeAssistantAPI.rejectedReconnectDelays = [0, 0, 0]
        defer { HomeAssistantAPI.rejectedReconnectDelays = priorDelays }

        let api = HomeAssistantAPI(server: .fake())
        let connection = RejectingMockConnection()
        connection.delegate = api
        api.connection = connection

        connection.setState(.disconnected(reason: .rejected))
        drainMainQueue(cycles: 20)

        // One reconnect per backoff entry, then we stop — a genuinely-invalid token must not loop forever
        // (which would keep tripping HA's auth-ban endpoint).
        XCTAssertEqual(connection.connectCount, 3)
        XCTAssertEqual(connection.state, .disconnected(reason: .rejected))
    }
}

/// A minimal `HAConnection` whose `connect()` always lands back in the rejected state, used to exercise
/// the reconnect-budget cap. `HAMockConnection` is `public` (not `open`), so it can't be subclassed here.
private final class RejectingMockConnection: HAConnection {
    weak var delegate: HAConnectionDelegate?
    var configuration: HAConnectionConfiguration = .fake
    var callbackQueue: DispatchQueue = .main
    private(set) var connectCount = 0
    lazy var caches: HACachesContainer = .init(connection: self)

    private(set) var state: HAConnectionState = .disconnected(reason: .disconnected) {
        didSet {
            callbackQueue.async { [self, state] in
                delegate?.connection(self, didTransitionTo: state)
            }
        }
    }

    func setState(_ state: HAConnectionState) {
        self.state = state
    }

    func connect() {
        connectCount += 1
        state = .disconnected(reason: .rejected)
    }

    func disconnect() {
        state = .disconnected(reason: .disconnected)
    }

    private func noopCancellable() -> HACancellable { HAMockCancellable {} }

    func send(_ request: HARequest, completion: @escaping (Swift.Result<HAData, HAError>) -> Void) -> HACancellable {
        noopCancellable()
    }

    func send<T>(
        _ request: HATypedRequest<T>,
        completion: @escaping (Swift.Result<T, HAError>) -> Void
    ) -> HACancellable {
        noopCancellable()
    }

    func subscribe(
        to request: HARequest,
        handler: @escaping (HACancellable, HAData) -> Void
    ) -> HACancellable {
        noopCancellable()
    }

    func subscribe(
        to request: HARequest,
        initiated: @escaping (Swift.Result<HAData, HAError>) -> Void,
        handler: @escaping (HACancellable, HAData) -> Void
    ) -> HACancellable {
        noopCancellable()
    }

    func subscribe<T>(
        to request: HATypedSubscription<T>,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        noopCancellable()
    }

    func subscribe<T>(
        to request: HATypedSubscription<T>,
        initiated: @escaping (Swift.Result<HAData, HAError>) -> Void,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        noopCancellable()
    }
}

class HAAPIAutomaticWebSocketConnectTests: XCTestCase {
    private func drainMainQueue(cycles: Int = 2) {
        let expectation = expectation(description: "drain main queue")

        func schedule(_ remaining: Int) {
            DispatchQueue.main.async {
                if remaining == 0 {
                    expectation.fulfill()
                } else {
                    schedule(remaining - 1)
                }
            }
        }

        schedule(cycles)
        wait(for: [expectation], timeout: 10.0)
    }

    func testAutomaticConnectStartsDisconnectedConnection() {
        let api = HomeAssistantAPI(server: .fake())
        let connection = HAMockConnection()
        api.connection = connection

        api.connectWebSocketIfNeeded()
        drainMainQueue()

        XCTAssertEqual(connection.state, .ready(version: "1.0-mock"))
    }

    func testAutomaticConnectPreservesWaitingToReconnectState() {
        let api = HomeAssistantAPI(server: .fake())
        let connection = HAMockConnection()
        api.connection = connection

        let expectedState = HAConnectionState.disconnected(reason: .waitingToReconnect(
            lastError: URLError(.cannotConnectToHost),
            atLatest: Date(timeIntervalSinceNow: 30),
            retryCount: 3
        ))
        connection.setState(expectedState)

        api.connectWebSocketIfNeeded()
        drainMainQueue()

        XCTAssertEqual(connection.state, expectedState)
    }

    func testAutomaticConnectPreservesRejectedState() {
        let api = HomeAssistantAPI(server: .fake())
        let connection = HAMockConnection()
        api.connection = connection

        connection.setState(.disconnected(reason: .rejected))

        api.connectWebSocketIfNeeded()
        drainMainQueue()

        XCTAssertEqual(connection.state, .disconnected(reason: .rejected))
    }

    func testRetryAwareConnectionDoesNotReconnectWhileBackoffIsActive() {
        let underlying = HAMockConnection()
        // The mock otherwise flips to `.connecting` on any send; disable that so the test observes only
        // RetryAwareHAConnection's own connect gating, not the mock's behavior.
        underlying.automaticallyTransitionToConnecting = false
        let connection = RetryAwareHAConnection(underlying: underlying)
        let expectedState = HAConnectionState.disconnected(reason: .waitingToReconnect(
            lastError: URLError(.cannotConnectToHost),
            atLatest: Date(timeIntervalSinceNow: 30),
            retryCount: 3
        ))
        underlying.setState(expectedState)

        _ = connection.send(.init(type: .webSocket("ping")), completion: { _ in })
        drainMainQueue()

        XCTAssertEqual(underlying.state, expectedState)
    }

    func testRetryAwareConnectionReconnectsSocketRequestsFromIdleDisconnectedState() {
        let underlying = HAMockConnection()
        let connection = RetryAwareHAConnection(underlying: underlying)

        _ = connection.send(.init(type: .webSocket("ping")), completion: { _ in })
        drainMainQueue()

        XCTAssertEqual(underlying.state, .ready(version: "1.0-mock"))
    }

    func testRetryAwareConnectionDoesNotConnectRestRequests() {
        let underlying = HAMockConnection()
        // The mock otherwise flips to `.connecting` on any send; disable that so the test observes only
        // RetryAwareHAConnection's own connect gating, not the mock's behavior.
        underlying.automaticallyTransitionToConnecting = false
        let connection = RetryAwareHAConnection(underlying: underlying)

        _ = connection.send(.init(type: .rest(.get, "config")), completion: { _ in })
        drainMainQueue()

        XCTAssertEqual(underlying.state, .disconnected(reason: .disconnected))
        XCTAssertEqual(underlying.pendingRequests.count, 1)
    }
}
