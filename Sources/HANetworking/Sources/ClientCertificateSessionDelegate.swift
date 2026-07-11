import Alamofire
import Foundation

/// Custom SessionDelegate that handles client certificate authentication (mTLS)
open class ClientCertificateSessionDelegate: SessionDelegate, @unchecked Sendable {
    private let server: Server

    public init(server: Server) {
        self.server = server
        super.init()
    }

    override open func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Handle client certificate challenge
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            handleClientCertificateChallenge(challenge, completionHandler: completionHandler)
            return
        }

        // Let parent handle other challenges (server trust, etc.)
        super.urlSession(session, task: task, didReceive: challenge, completionHandler: completionHandler)
    }

    private func handleClientCertificateChallenge(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let clientCertificate = server.info.connection.clientCertificate else {
            HANetworkingEnvironment.current.log.warning("[mTLS] Client certificate requested but none configured for server")
            completionHandler(.performDefaultHandling, nil)
            return
        }

        do {
            let credential = try ClientCertificateManager.shared.urlCredential(for: clientCertificate)
            HANetworkingEnvironment.current.log.info("[mTLS] Using client certificate: \(clientCertificate.displayName)")
            completionHandler(.useCredential, credential)
        } catch {
            HANetworkingEnvironment.current.log.error("[mTLS] Failed to get credential for client certificate: \(error)")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
