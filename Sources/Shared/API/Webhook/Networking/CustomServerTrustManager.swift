import Alamofire
import Foundation

final class CustomServerTrustManager: ServerTrustManager, ServerTrustEvaluating {
    let exceptions: () -> SecurityExceptions

    init(server: Server) {
        self.exceptions = { server.info.connection.securityExceptions }
        super.init(evaluators: [:])
    }

    init(exceptions: SecurityExceptions) {
        self.exceptions = { exceptions }
        super.init(evaluators: [:])
    }

    override func serverTrustEvaluator(forHost host: String) -> ServerTrustEvaluating? {
        self
    }

    func evaluate(_ trust: SecTrust, forHost host: String) throws {
        try exceptions().evaluate(trust)
    }
}
