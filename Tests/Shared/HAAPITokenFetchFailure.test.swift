import Alamofire
import HAKit
@testable import Shared
import XCTest

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
        let connection = RetryAwareHAConnection(underlying: underlying)

        _ = connection.send(.init(type: .rest(.get, "config")), completion: { _ in })
        drainMainQueue()

        XCTAssertEqual(underlying.state, .disconnected(reason: .disconnected))
        XCTAssertEqual(underlying.pendingRequests.count, 1)
    }
}
