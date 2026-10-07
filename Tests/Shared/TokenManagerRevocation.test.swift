import Foundation
@testable import Shared
import XCTest

class TokenManagerRevocationTests: XCTestCase {
    /// Logging out revokes the refresh token, and with it every access token minted from it, so the
    /// stored token must never be handed out again — the app would otherwise keep signing requests
    /// with it while the user logs back in, which the server logs as invalid auth.
    func testRevokedTokenIsNotProvidedAgain() {
        let server = Server.fake(update: { info in
            info.connection.set(address: nil, for: .external)
        })
        let tokenManager = TokenManager(server: server)
        let revokedToken = server.info.token.accessToken

        tokenManager.handleTokenRevoked()

        let settled = expectation(description: "bearerToken settled")
        tokenManager.bearerToken.done { token, _ in
            XCTAssertNotEqual(token, revokedToken)
            settled.fulfill()
        }.catch { _ in
            // Refresh failing (no reachable server in tests) is the acceptable outcome; what matters
            // is that the revoked token was not fulfilled.
            settled.fulfill()
        }

        wait(for: [settled], timeout: 5)
    }

    /// The expiration is pushed into the past so the invalidation reaches the processes that read the
    /// store fresh, but the token strings stay: clearing those is what the keychain-mirror placeholder
    /// is, and it would send the app to the recovered-server import flow at launch instead of the
    /// logged-out state.
    func testRevocationInvalidatesExpirationWithoutBlankingTheToken() {
        let server = Server.fake()
        let tokenManager = TokenManager(server: server)
        let token = server.info.token

        tokenManager.handleTokenRevoked()

        XCTAssertEqual(server.info.token.accessToken, token.accessToken)
        XCTAssertEqual(server.info.token.refreshToken, token.refreshToken)
        XCTAssertEqual(server.info.token.expiration, .distantPast)
        XCTAssertFalse(server.info.requiresReauthenticationAfterMirrorRestore)
    }
}
