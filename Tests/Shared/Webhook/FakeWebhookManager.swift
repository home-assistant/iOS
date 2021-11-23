import Foundation
import PromiseKit
@testable import Shared

class FakeWebhookManager: WebhookManager {
    var sendRequestHandler: ((WebhookResponseIdentifier, Server, WebhookRequest, Resolver<Void>) -> Void)?

    override func send(
        identifier: WebhookResponseIdentifier = .unhandled,
        server: Server,
        request: WebhookRequest
    ) -> Promise<Void> {
        let (promise, seal) = Promise<Void>.pending()
        sendRequestHandler?(identifier, server, request, seal)
        return promise
    }
}
