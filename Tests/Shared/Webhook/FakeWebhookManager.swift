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

    /// Answers with the JSON a server would have returned. The typed `sendEphemeral` overloads all
    /// funnel through this one, so callers still go through the real response mapping.
    var sendEphemeralHandler: ((Server, WebhookRequest) -> Any)?

    override func sendEphemeral<ResponseType>(
        server: Server,
        request: WebhookRequest,
        overrideURL: URL? = nil
    ) -> Promise<ResponseType> {
        guard let response = sendEphemeralHandler?(server, request) as? ResponseType else {
            return .init(error: FakeWebhookManagerError.noEphemeralResponse)
        }

        return .value(response)
    }
}

enum FakeWebhookManagerError: Error {
    case noEphemeralResponse
}
