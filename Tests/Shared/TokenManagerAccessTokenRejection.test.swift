import Alamofire
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

    /// The real server store drops a write whose `ServerInfo` compares equal to what it already has,
    /// and `TokenInfo` equality ignores the expiration — so pushing the expiration into the past does
    /// not persist. The rejection must hold anyway, or every later request re-sends the rejected token.
    func testRejectedTokenIsNotProvidedWhenStoreDropsExpirationOnlyWrites() {
        let server = Self.serverDroppingWritesThatCompareEqual()
        let tokenManager = TokenManager(server: server)
        let rejectedToken = server.info.token.accessToken

        tokenManager.handleAccessTokenRejected(rejectedToken)
        XCTAssertGreaterThan(server.info.token.expiration, Current.date())

        let settled = expectation(description: "bearerToken settled")
        tokenManager.bearerToken.done { token, _ in
            XCTAssertNotEqual(token, rejectedToken)
            settled.fulfill()
        }.catch { _ in
            settled.fulfill()
        }

        wait(for: [settled], timeout: 5)
    }

    /// Re-authentication stores a brand new token without going through the token manager, so requests
    /// signed by a session built before it must still carry the new token — otherwise the rejected one
    /// keeps going out until the app is relaunched.
    func testInterceptorSignsRequestsWithTheTokenStoredAfterReauthentication() throws {
        let url = try XCTUnwrap(URL(string: "http://homeassistant.local:8123/api/"))
        let server = Server.fake()
        let tokenManager = TokenManager(server: server)
        let interceptor = tokenManager.authenticationInterceptor

        server.update { info in
            info.token = .init(
                accessToken: "ReauthenticatedAccessToken",
                refreshToken: "ReauthenticatedRefreshToken",
                expiration: Current.date().addingTimeInterval(3600)
            )
        }

        let adapted = expectation(description: "request adapted")
        interceptor.adapt(URLRequest(url: url), for: Session.default) { result in
            let authorization = try? result.get().value(forHTTPHeaderField: "Authorization")
            XCTAssertEqual(authorization, "Bearer ReauthenticatedAccessToken")
            adapted.fulfill()
        }

        wait(for: [adapted], timeout: 5)
    }

    /// A `Server` whose setter behaves like `ServerManagerImpl`'s: a value that compares equal to the
    /// stored one is discarded, which is what makes an expiration-only update a no-op in the app.
    private static func serverDroppingWritesThatCompareEqual() -> Server {
        var stored = ServerInfo.fake()
        // No reachable URL, so the refresh the rejection forces fails fast instead of hitting the network.
        stored.connection.set(address: nil, for: .external)
        return Server(
            identifier: .init(rawValue: UUID().uuidString),
            getter: { stored },
            setter: { newValue in
                guard newValue != stored else { return false }
                stored = newValue
                return true
            }
        )
    }
}
