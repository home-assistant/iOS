import Foundation
import PromiseKit
import Starscream

internal struct WebSocketRequestIdentifier: RawRepresentable, Hashable {
    let rawValue: Int
}

public class WebSocketAPI: WebSocketDelegate {
    internal var callbackQueue: DispatchQueue = .main
    internal let connection: WebSocket
    internal let tokenManager: TokenManager

    enum Phase {
        case disconnected
        case auth
        case command
    }

    enum PhaseTransitionError: Error {
        case disconnected
    }

    private var phase: Phase = .disconnected {
        didSet {
            Current.Log.info("phase transition to \(phase)")

            switch phase {
            case .auth:
                break
            case .disconnected:
                discardActiveItems()
            case .command:
                applyPendingItems()
            }
        }
    }

    init(tokenManager: TokenManager) {
        let specificKey = DispatchSpecificKey<Bool>()
        self.dataQueue = with(DispatchQueue(label: "websocket-api-data")) {
            $0.setSpecific(key: specificKey, value: true)
        }
        self.dataQueueSpecificKey = specificKey

        self.tokenManager = tokenManager
        self.connection = WebSocket(request: URLRequest(url: URL(string: "http://127.0.0.1:8123/api/websocket")!))
        self.connection.delegate = self
        self.connection.callbackQueue = dataQueue

        // xxx test
        _ = subscribe(to: nil) { registration, event in
            print("*** \(registration) received \(event)")
        }

        send(.init(type: .getConfig, data: [:])).done { data in
            print("*** get_config: \(data)")
        }.catch { error in
            print("*** failed get_config: \(error)")
        }
        // xxx test

        self.connection.connect()
    }

    public func send(_ request: WebSocketRequest) -> Promise<WebSocketData> {
        Current.Log.info("enqueue request \(request)")

        let (promise, seal) = Promise<WebSocketData>.pending()

        dataQueue.async {
            self.pendingRequests.append(.init(
                request: request,
                resolver: seal
            ))
        }

        return promise
    }

    public func subscribe(
        to event: WebSocketEventType?,
        handler: @escaping WebSocketEventHandler
    ) -> WebSocketEventRegistration {
        Current.Log.info("subscribe to \(event?.rawValue ?? "(all)")")

        let registration = WebSocketEventRegistration(
            type: event,
            handler: handler
        )

        dataQueue.async {
            self.eventRegistrations.append(registration)
        }

        return registration
    }

    public func unsubscribe(
        _ registration: WebSocketEventRegistration
    ) {
        Current.Log.info("unsubscribe \(registration)")

        dataQueue.async {
            if let identifier = registration.subscriptionIdentifier {
                self.eventRegistrations.removeAll(where: { $0 == registration })
                self.activeEventRegistrations[identifier] = nil
                registration.subscriptionIdentifier = nil

                self.sendInternal(request: .init(type: .unsubscribeEvents, data: [
                    "subscription": identifier.rawValue
                ])).done {
                    Current.Log.info("end \(registration): \($0)")
                }.cauterize()
            } else {
                self.eventRegistrations.removeAll(where: { $0 == registration })
                Current.Log.info("ended non-pending \(registration)")
            }
        }
    }

    private func sendInternal(
        forcedIdentifier: WebSocketRequestIdentifier? = nil,
        request: WebSocketRequest
    ) -> Promise<WebSocketData> {
        precondition(DispatchQueue.getSpecific(key: dataQueueSpecificKey) == true)

        Current.Log.info("send \(request)")

        return Promise { seal in
            let identifier = forcedIdentifier ?? self.identifiers.next()
            self.activeRequests[identifier] = seal

            var data = request.data
            data["id"] = identifier.rawValue
            data["type"] = request.type.rawValue

            self.sendRaw(data).catch { error in
                seal.reject(error)
            }
        }
    }

    private func sendRaw(_ dictionary: [String: Any]) -> Promise<Void> {
        Promise { seal in
            do {
                let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
                connection.write(string: String(data: data, encoding: .utf8) ?? "", completion: {
                    seal.fulfill(())
                })
            } catch {
                seal.reject(error)
            }
        }
    }

    private func discardActiveItems() {
        for registration in eventRegistrations {
            registration.subscriptionIdentifier = nil
        }
        for request in pendingRequests {
            request.requestIdentifier = nil
        }
        activeEventRegistrations.removeAll()
        activeRequests.removeAll()
    }

    private func applyPendingItems() {
        precondition(DispatchQueue.getSpecific(key: dataQueueSpecificKey) == true)

        guard phase == .command else {
            Current.Log.verbose("not applying pending items because phase is \(phase)")
            return
        }

        for registration in eventRegistrations where registration.subscriptionIdentifier == nil {
            var data: [String: Any] = [:]

            if let type = registration.type {
                data["event_type"] = type.rawValue
            }

            let identifier = identifiers.next()
            registration.subscriptionIdentifier = identifier

            Current.Log.info("reconnecting \(registration)")

            firstly {
                sendInternal(forcedIdentifier: identifier, request: .init(type: .subscribeEvents, data: data))
            }.done(on: dataQueue) { _ in
                self.activeEventRegistrations[identifier] = registration
            }.catch { error in
                registration.subscriptionIdentifier = nil
                Current.Log.error("failed to subscribe \(registration): \(error)")
            }
        }

        for request in pendingRequests where request.requestIdentifier == nil {
            let identifier = identifiers.next()
            request.requestIdentifier = identifier

            Current.Log.info("sending request \(request)")

            firstly {
                sendInternal(forcedIdentifier: identifier, request: request.request)
            }.pipe {
                request.resolver.resolve($0)
            }
        }
    }

    private enum HandleError: Error {
        case missingKey(String)
        case responseErrorUnknown
        case responseError(code: Int, message: String)
    }

    private func handle(response: [String: Any]) throws {
        Current.Log.verbose("received \(response)")

        switch try WebSocketResponse(dictionary: response) {
        case .result(identifier: let identifier, data: let result):
            if let resolver = activeRequests[identifier] {
                activeRequests[identifier] = nil
                callbackQueue.async {
                    resolver.resolve(result)
                }
            } else {
                Current.Log.error("no resolver for response \(identifier)")
            }
        case .event(identifier: let identifier, event: let event):
            if let registration = activeEventRegistrations[identifier] {
                callbackQueue.async {
                    registration.fire(event)
                }
            } else {
                Current.Log.error("no handler for event \(event)")
            }
        case .auth(let authState):
            switch authState {
            case .required, .invalid:
                tokenManager.bearerToken(forceRefresh: authState == .invalid).done { token in
                    self.sendRaw([
                        "type": "auth",
                        "access_token": token
                    ]).cauterize()
                }.catch { error in
                    Current.Log.error("couldn't retrieve auth token, disconnecting")
                    self.connection.disconnect(closeCode: CloseCode.goingAway.rawValue)
                }
            case .ok:
                phase = .command
            }
        }
    }

    private struct IdentifierGenerator {
        private var lastIdentifierInteger = 0

        mutating func next() -> WebSocketRequestIdentifier {
            lastIdentifierInteger += 1
            return .init(rawValue: lastIdentifierInteger)
        }
    }

    private var identifiers = IdentifierGenerator() {
        willSet {
            assert(DispatchQueue.getSpecific(key: dataQueueSpecificKey) == true)
        }
    }

    private var pendingRequests = [WebSocketPendingRequest]() {
        willSet {
            assert(DispatchQueue.getSpecific(key: dataQueueSpecificKey) == true)
        }
        didSet {
            applyPendingItems()
        }
    }
    private var eventRegistrations = [WebSocketEventRegistration]() {
        willSet {
            assert(DispatchQueue.getSpecific(key: dataQueueSpecificKey) == true)
        }
        didSet {
            applyPendingItems()
        }
    }

    private var activeRequests = [WebSocketRequestIdentifier: Resolver<WebSocketData>]() {
        willSet {
            assert(DispatchQueue.getSpecific(key: dataQueueSpecificKey) == true)
        }
    }
    private var activeEventRegistrations = [WebSocketRequestIdentifier: WebSocketEventRegistration]() {
        willSet {
            assert(DispatchQueue.getSpecific(key: dataQueueSpecificKey) == true)
        }
    }
    private let dataQueue: DispatchQueue
    private let dataQueueSpecificKey: DispatchSpecificKey<Bool>

    public func didReceive(event: Starscream.WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(let headers):
            Current.Log.info("connected with headers: \(headers)")
            phase = .auth
        case .disconnected(let reason, let code):
            Current.Log.info("disconnected: \(reason) with code: \(code)")
            phase = .disconnected
        case .text(let string):
            print("Received text: \(string)")
            if let data = string.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                _ = try? self.handle(response: json)
            }
        case .binary(let data):
            print("Received binary data: \(data.count)")
        case .ping, .pong:
            break
        case .reconnectSuggested:
            break
        case .viabilityChanged:
            break
        case .cancelled:
            phase = .disconnected
        case .error(let error):
            Current.Log.error("connection error: \(String(describing: error))")
            phase = .disconnected
        }

    }
}
