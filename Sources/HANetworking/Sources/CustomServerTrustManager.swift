import Alamofire
import Foundation
import Security

public final class CustomServerTrustManager: ServerTrustManager, ServerTrustEvaluating, @unchecked Sendable {
    let exceptions: () -> SecurityExceptions

    public init(server: Server) {
        self.exceptions = { server.info.connection.securityExceptions }
        super.init(evaluators: [:])
    }

    public init(exceptions: SecurityExceptions) {
        self.exceptions = { exceptions }
        super.init(evaluators: [:])
    }

    override public func serverTrustEvaluator(forHost host: String) -> ServerTrustEvaluating? {
        self
    }

    public func evaluate(_ trust: SecTrust, forHost host: String) throws {
        try exceptions().evaluate(trust)
    }
}
