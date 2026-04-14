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
