import Foundation
import PromiseKit
@testable import Shared

class FakeWebhookManager: WebhookManager {
    var sendRequestHandler: ((WebhookResponseIdentifier, WebhookRequest, Resolver<Void>) -> Void)?

    override func send(identifier: WebhookResponseIdentifier = .unhandled, request: WebhookRequest) -> Promise<Void> {
        let (promise, seal) = Promise<Void>.pending()
        sendRequestHandler?(identifier, request, seal)
        return promise
    }
}
