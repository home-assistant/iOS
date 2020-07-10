import Foundation
import PromiseKit

internal enum WebSocketResponse {
    enum AuthState {
        case required
        case ok
        case invalid
    }

    enum WebSocketResponseError: Error {
        case parseError(Error?)
        case unknownType(String)
        case responseError(error: (Int, String)?)
    }

    case result(identifier: WebSocketRequestIdentifier, data: PromiseKit.Result<WebSocketData>)
    case event(identifier: WebSocketRequestIdentifier, event: WebSocketEvent)
    case auth(AuthState)

    init(dictionary: [String: Any]) throws {
        guard let type = dictionary["type"] as? String else {
            throw WebSocketResponseError.parseError(nil)
        }

        func parseIdentifier() throws -> WebSocketRequestIdentifier {
            if let value = (dictionary["id"] as? Int).flatMap(WebSocketRequestIdentifier.init(rawValue:)) {
                return value
            } else {
                throw WebSocketResponseError.parseError(nil)
            }
        }

        switch type {
        case "result":
            let identifier = try parseIdentifier()

            if dictionary["success"] as? Bool == true {
                self = .result(identifier: identifier, data: .fulfilled(.init(value: dictionary["result"])))
            } else {
                self = .result(identifier: identifier, data: .rejected(WebSocketResponseError.responseError(error: {
                    if let error = dictionary["error"] as? [String: Any],
                        let code = error["code"] as? Int,
                        let message = error["message"] as? String {
                        return (code, message)
                    } else {
                        return nil
                    }
                }())))
            }

        case "event":
            let identifier = try parseIdentifier()

            let event = try WebSocketEvent(dictionary: dictionary["event"] as? [String: Any] ?? [:])
            self = .event(identifier: identifier, event: event)
        case "auth_required":
            self = .auth(.required)
        case "auth_ok":
            self = .auth(.ok)
        case "auth_invalid":
            self = .auth(.invalid)
        default:
            throw WebSocketResponseError.unknownType(type)
        }
    }
}
