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

    /// Blanking the stored token would make the server indistinguishable from one restored from the
    /// keychain mirror, which sends the app to the recovered-server import flow at launch instead of
    /// the logged-out state.
    func testRevocationLeavesStoredTokenInPlace() {
        let server = Server.fake()
        let tokenManager = TokenManager(server: server)
        let token = server.info.token

        tokenManager.handleTokenRevoked()

        XCTAssertEqual(server.info.token, token)
        XCTAssertFalse(server.info.requiresReauthenticationAfterMirrorRestore)
    }
}
