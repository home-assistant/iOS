import Foundation
import PromiseKit

internal struct WebSocketRequestIdentifier: RawRepresentable, Hashable {
    let rawValue: Int
}

public class WebSocketAPI {
    public typealias WebSocketEventHandler = (WebSocketEvent) -> Void

    public func send(_ request: WebSocketRequest) -> Promise<WebSocketData> {
        sendInternal(request).map { $1 }
    }

    public func subscribe(
        to event: WebSocketEventType?,
        handler: @escaping WebSocketEventHandler
    ) -> Promise<WebSocketEventRegistration> {
        Current.Log.info("start \(event?.rawValue ?? "(all)")")

        var data: [String: String] = [:]

        if let event = event {
            data["event_type"] = event.rawValue
        }

        return sendInternal(.init(
            type: .subscribeEvents,
            data: data
        )).map(on: dataQueue) { identifier, data in
            Current.Log.info("confirmed \(event?.rawValue ?? "(all)") as \(identifier.rawValue): \(data)")
            self.eventHandlers[identifier] = handler
            return WebSocketEventRegistration.init(identifier: identifier, api: self)
        }
    }

    public func unsubscribe(
        _ registration: WebSocketEventRegistration
    ) {
        Current.Log.info("start \(registration.identifier)")

        let remove = Promise<Void> { seal in
            dataQueue.async {
                self.eventHandlers[registration.identifier] = nil
                seal.fulfill(())
            }
        }

        let unsubscribe = sendInternal(.init(
            type: .unsubscribeEvents,
            data: [
                "subscription": registration.identifier.rawValue
            ]
        ))

        firstly {
            when(fulfilled: remove, unsubscribe)
        }.done {
            Current.Log.info("end \(registration.identifier): \($0) \($1)")
        }.cauterize()
    }

    private func sendInternal(_ request: WebSocketRequest) -> Promise<(WebSocketRequestIdentifier, WebSocketData)> {
        Current.Log.info("send \(request)")

        return Promise { seal in
            dataQueue.async {
                let identifier = self.identifiers.next()
                self.pendingResults[identifier] = seal

                // todo: network op
                Current.Log.info("dropping \(request)")
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
        
        func valueOrThrow<T>(key: String) throws -> T {
            if let value = response[key] as? T {
                return value
            } else {
                throw HandleError.missingKey(key)
            }
        }

        let identifier = WebSocketRequestIdentifier(rawValue: try valueOrThrow(key: "id"))
        let type: String = try valueOrThrow(key: "type")

        switch type {
        case "result":
            guard let resolver = pendingResults[identifier] else {
                Current.Log.error("couldn't find resolver for \(identifier)")
                return
            }

            let success: Bool = try valueOrThrow(key: "success")

            if success {
                resolver.fulfill((identifier, .init(value: response["result"])))
            } else {
                if let error = response["error"] as? [String: Any],
                    let code = error["code"] as? Int,
                    let message = error["message"] as? String {
                    resolver.reject(HandleError.responseError(code: code, message: message))
                } else {
                    resolver.reject(HandleError.responseErrorUnknown)
                }
            }

            pendingResults[identifier] = nil
        case "event":
            guard let handler = eventHandlers[identifier] else {
                Current.Log.error("couldn't find event handler for \(identifier)")
                return
            }

            guard let event = WebSocketEvent(
                registration: .init(identifier: identifier, api: self),
                dictionary: try valueOrThrow(key: "event")
            ) else {
                Current.Log.error("couldn't parse event out of \(response)")
                return
            }

            handler(event)
        default:
            Current.Log.error("unknown response type \(type)")
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
    private var pendingResults = [WebSocketRequestIdentifier: Resolver<(WebSocketRequestIdentifier, WebSocketData)>]() {
        willSet {
            assert(DispatchQueue.getSpecific(key: dataQueueSpecificKey) == true)
        }
    }
    private var eventHandlers = [WebSocketRequestIdentifier: WebSocketEventHandler]() {
        willSet {
            assert(DispatchQueue.getSpecific(key: dataQueueSpecificKey) == true)
        }
    }
    private let dataQueue = DispatchQueue(label: "websocket-api-data")
    private let dataQueueSpecificKey = DispatchSpecificKey<Bool>()
}
