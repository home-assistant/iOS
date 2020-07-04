import Foundation
import PromiseKit
import UserNotifications

public struct WebhookResponseIdentifier: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    private static let headerKey = "WebhookResponseIdentifier"

    internal init?(request: URLRequest) {
        if let rawValue = request.allHTTPHeaderFields?[Self.headerKey] {
            // should i keep abusing headers for this or should i persist it somewhere, idk
            self.rawValue = rawValue
        } else {
            return nil
        }
    }
    internal func augment(request: inout URLRequest) {
        request.setValue(rawValue, forHTTPHeaderField: Self.headerKey)
    }
}

public struct WebhookResponseHandlerResult {
    static var `default`: Self { .init() }
    public var notification: UNNotificationRequest?
}

public protocol WebhookResponseHandler {
    static func shouldReplace(request current: URLSessionTask, with proposed: URLSessionTask) -> Bool

    init(api: HomeAssistantAPI)
    func handle(result: Promise<Any>) -> Guarantee<WebhookResponseHandlerResult>
}
