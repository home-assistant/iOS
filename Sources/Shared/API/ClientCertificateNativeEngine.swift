import Foundation
import HAKit
import Starscream

/// App-specific wrapper that bridges ClientCertificate to HAClientCertificateEngine.
@available(iOS 13.0, watchOS 6.0, *)
public final class ClientCertificateNativeEngine: NSObject, Engine {
    private let haEngine: HAClientCertificateEngine

    public init(clientCertificate: ClientCertificate?, securityExceptions: SecurityExceptions) {
        let identity: SecIdentity? = {
            guard let cert = clientCertificate else { return nil }
            return ClientCertificateManager.shared.readIdentity(name: cert.name)
        }()

        self.haEngine = HAClientCertificateEngine(
            clientIdentity: identity,
            evaluateServerTrust: { serverTrust in
                try securityExceptions.evaluate(serverTrust)
            }
        )
        super.init()
    }

    public func register(delegate: EngineDelegate) {
        haEngine.register(delegate: delegate)
    }

    public func start(request: URLRequest) {
        haEngine.start(request: request)
    }

    public func stop(closeCode: UInt16) {
        haEngine.stop(closeCode: closeCode)
    }

    public func forceStop() {
        haEngine.forceStop()
    }

    public func write(string: String, completion: (() -> Void)?) {
        haEngine.write(string: string, completion: completion)
    }

    public func write(data: Data, opcode: FrameOpCode, completion: (() -> Void)?) {
        haEngine.write(data: data, opcode: opcode, completion: completion)
    }
}
