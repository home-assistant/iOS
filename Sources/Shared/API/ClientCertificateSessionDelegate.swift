import Alamofire
import Foundation

#if !os(watchOS)
/// Custom SessionDelegate that handles client certificate authentication (mTLS)
public class ClientCertificateSessionDelegate: SessionDelegate {
    private let server: Server
    
    public init(server: Server) {
        self.server = server
        super.init()
    }
    
    public override func urlSession(
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
            Current.Log.warning("[mTLS] Client certificate requested but none configured for server")
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        do {
            let credential = try ClientCertificateManager.shared.urlCredential(for: clientCertificate)
            Current.Log.info("[mTLS] Using client certificate: \(clientCertificate.displayName)")
            completionHandler(.useCredential, credential)
        } catch {
            Current.Log.error("[mTLS] Failed to get credential for client certificate: \(error)")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
#endif
