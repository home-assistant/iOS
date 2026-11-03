import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

/// Reachability checks answer authentication challenges the way the server's connection does.
struct WebhookReachabilitySessionDelegateTests {
    private final class Sender: NSObject, URLAuthenticationChallengeSender {
        func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
        func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
        func cancel(_ challenge: URLAuthenticationChallenge) {}
    }

    @Test func answersAChallengeWithTheConnectionsDecision() {
        let connection = ServerInfo.fake().connection
        let delegate = WebhookReachabilitySessionDelegate(connection: connection)
        let challenge = URLAuthenticationChallenge(
            protectionSpace: URLProtectionSpace(
                host: "example.com",
                port: 443,
                protocol: NSURLProtectionSpaceHTTPS,
                realm: nil,
                authenticationMethod: NSURLAuthenticationMethodHTTPBasic
            ),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: Sender()
        )
        let expected = connection.evaluate(challenge)

        var answer: (URLSession.AuthChallengeDisposition, URLCredential?)?
        delegate.urlSession(URLSession.shared, didReceive: challenge) { answer = ($0, $1) }
        #expect(answer?.0 == expected.0)
        #expect(answer?.1 == expected.1)
    }
}
