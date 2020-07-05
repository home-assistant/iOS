import Foundation
import PromiseKit
import UserNotifications

public struct WebhookResponseIdentifier: RawRepresentable, Hashable, Codable {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct WebhookResponseHandlerResult {
    static var `default`: Self { .init() }
    public var notification: UNNotificationRequest?
}

public protocol WebhookResponseHandler {
    static func shouldReplace(request current: WebhookRequest, with proposed: WebhookRequest) -> Bool

    init(api: HomeAssistantAPI)
    func handle(
        request: Promise<WebhookRequest>,
        result: Promise<Any>
    ) -> Guarantee<WebhookResponseHandlerResult>
}
