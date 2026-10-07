import Foundation
import Shared

/// Applies the server's TLS material — the mTLS client certificate and any self-signed certificate
/// exceptions the user accepted — to reachability checks, so checking a URL behaves the same way the
/// real webhook requests do instead of failing on trust alone.
final class WebhookReachabilitySessionDelegate: NSObject, URLSessionDelegate {
    private let connection: ConnectionInfo

    init(connection: ConnectionInfo) {
        self.connection = connection
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let (disposition, credential) = connection.evaluate(challenge)
        completionHandler(disposition, credential)
    }
}
