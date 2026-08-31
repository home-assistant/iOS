import Foundation
import PromiseKit
@testable import Shared

class FakeWebhookManager: WebhookManager {
    var sendRequestHandler: ((WebhookResponseIdentifier, Server, WebhookRequest, Resolver<Void>) -> Void)?
    private(set) var sendCount = 0
    private(set) var startPersistedBackgroundCount = 0

    override func send(
        identifier: WebhookResponseIdentifier = .unhandled,
        server: Server,
        request: WebhookRequest
    ) -> Promise<Void> {
        sendCount += 1
        let (promise, seal) = Promise<Void>.pending()
        sendRequestHandler?(identifier, server, request, seal)
        return promise
    }

    override func startPersistedBackground(
        identifier: WebhookResponseIdentifier = .unhandled,
        server: Server,
        request: WebhookRequest,
        requestTimeout: TimeInterval? = nil
    ) -> Swift.Result<Promise<Void>, Error> {
        startPersistedBackgroundCount += 1
        let (promise, seal) = Promise<Void>.pending()
        sendRequestHandler?(identifier, server, request, seal)
        return .success(promise)
    }
}
