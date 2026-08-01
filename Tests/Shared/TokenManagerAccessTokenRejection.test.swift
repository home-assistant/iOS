import Foundation
@testable import Shared
import XCTest

class TokenManagerAccessTokenRejectionTests: XCTestCase {
    /// A 401 for the currently stored token must expire it, so no later request re-sends a token the
    /// server already rejected (repeats get logged as invalid auth and eventually IP-banned).
    func testRejectingCurrentTokenExpiresIt() {
        let server = Server.fake()
        let tokenManager = TokenManager(server: server)

        XCTAssertGreaterThan(server.info.token.expiration, Date())
        tokenManager.handleAccessTokenRejected(server.info.token.accessToken)

        XCTAssertEqual(server.info.token.expiration, .distantPast)
    }

    /// A 401 for a token that a concurrent refresh already replaced must not clobber the fresh
    /// token's expiration.
    func testRejectingSupersededTokenIsIgnored() {
        let server = Server.fake()
        let tokenManager = TokenManager(server: server)
        let expiration = server.info.token.expiration

        tokenManager.handleAccessTokenRejected("OlderTokenAlreadyReplaced")

        XCTAssertEqual(server.info.token.expiration, expiration)
    }

    /// Once rejected, `bearerToken` must not hand the token out again — it must go through the
    /// refresh path instead (which here fails fast for lack of a server, rather than fulfilling
    /// with the rejected token).
    func testBearerTokenDoesNotProvideRejectedToken() {
        let server = Server.fake(update: { info in
            info.connection.set(address: nil, for: .external)
        })
        let tokenManager = TokenManager(server: server)
        let rejectedToken = server.info.token.accessToken
        tokenManager.handleAccessTokenRejected(rejectedToken)

        let settled = expectation(description: "bearerToken settled")
        tokenManager.bearerToken.done { token, _ in
            XCTAssertNotEqual(token, rejectedToken)
            settled.fulfill()
        }.catch { _ in
            // Refresh failing (no reachable server in tests) is the acceptable outcome; what matters
            // is that the rejected token was not fulfilled.
            settled.fulfill()
        }

        wait(for: [settled], timeout: 5)
    }
}
