import Foundation
import HAKit
import Starscream

/// Custom WebSocket engine that supports mTLS client certificate authentication.
/// This wraps URLSession's native WebSocket support and handles authentication challenges.
@available(iOS 13.0, watchOS 6.0, *)
public final class ClientCertificateNativeEngine: NSObject, Engine, URLSessionDataDelegate, URLSessionWebSocketDelegate {
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private weak var delegate: EngineDelegate?
    private let clientCertificate: ClientCertificate?
    private let securityExceptions: SecurityExceptions
    
    public init(clientCertificate: ClientCertificate?, securityExceptions: SecurityExceptions) {
        self.clientCertificate = clientCertificate
        self.securityExceptions = securityExceptions
        super.init()
    }
    
    public func register(delegate: EngineDelegate) {
        self.delegate = delegate
    }
    
    public func start(request: URLRequest) {
        if session == nil {
            session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        }
        task = session?.webSocketTask(with: request)
        doRead()
        task?.resume()
    }
    
    public func stop(closeCode: UInt16) {
        let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: Int(closeCode)) ?? .normalClosure
        task?.cancel(with: closeCode, reason: nil)
    }
    
    public func forceStop() {
        stop(closeCode: UInt16(URLSessionWebSocketTask.CloseCode.abnormalClosure.rawValue))
    }
    
    public func write(string: String, completion: (() -> ())?) {
        task?.send(.string(string), completionHandler: { _ in
            completion?()
        })
    }
    
    public func write(data: Data, opcode: FrameOpCode, completion: (() -> ())?) {
        switch opcode {
        case .binaryFrame:
            task?.send(.data(data), completionHandler: { _ in
                completion?()
            })
        case .textFrame:
            if let text = String(data: data, encoding: .utf8) {
                write(string: text, completion: completion)
            }
        case .ping:
            task?.sendPing(pongReceiveHandler: { _ in
                completion?()
            })
        default:
            break
        }
    }
    
    private func doRead() {
        task?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let string):
                    self?.broadcast(event: .text(string))
                case .data(let data):
                    self?.broadcast(event: .binary(data))
                @unknown default:
                    break
                }
            case .failure(let error):
                self?.broadcast(event: .error(error))
                return
            }
            self?.doRead()
        }
    }
    
    private func broadcast(event: WebSocketEvent) {
        delegate?.didReceive(event: event)
    }
    
    // MARK: - URLSessionWebSocketDelegate
    
    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol proto: String?
    ) {
        let protocolHeader = proto ?? ""
        broadcast(event: .connected(["Sec-WebSocket-Protocol": protocolHeader]))
    }
    
    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        var reasonString = ""
        if let reasonData = reason {
            reasonString = String(data: reasonData, encoding: .utf8) ?? ""
        }
        broadcast(event: .disconnected(reasonString, UInt16(closeCode.rawValue)))
    }
    
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        broadcast(event: .error(error))
    }
    
    // MARK: - URLSessionDelegate Authentication Challenge
    
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        Current.Log.verbose("ClientCertificateNativeEngine: Received challenge: \(challenge.protectionSpace.authenticationMethod)")
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            Current.Log.info("ClientCertificateNativeEngine: Client certificate challenge")
            if let cert = clientCertificate,
               let credential = ClientCertificateManager.shared.credential(for: cert) {
                Current.Log.info("ClientCertificateNativeEngine: Using certificate: \(cert.name)")
                completionHandler(.useCredential, credential)
                return
            } else {
                Current.Log.warning("ClientCertificateNativeEngine: No client certificate available")
            }
            completionHandler(.performDefaultHandling, nil)
        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            // Handle server trust validation using security exceptions
            if let serverTrust = challenge.protectionSpace.serverTrust {
                do {
                    try securityExceptions.evaluate(serverTrust)
                    let credential = URLCredential(trust: serverTrust)
                    completionHandler(.useCredential, credential)
                } catch {
                    Current.Log.error("ClientCertificateNativeEngine: Server trust validation failed: \(error)")
                    completionHandler(.cancelAuthenticationChallenge, nil)
                }
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
