import Foundation
import PromiseKit
@testable import Shared

class FakeWebhookManager: WebhookManager {
    var sendRequestHandler: ((WebhookResponseIdentifier, Server, WebhookRequest, Resolver<Void>) -> Void)?
    private(set) var sendCount = 0
    private(set) var startPersistedBackgroundCount = 0
    private(set) var persistedRequestIdentifiers = [String?]()

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
        requestIdentifier: String? = nil,
        requestTimeout: TimeInterval? = nil
    ) -> Swift.Result<Task<Void, Error>, Error> {
        startPersistedBackgroundCount += 1
        persistedRequestIdentifiers.append(requestIdentifier)
        let (promise, seal) = Promise<Void>.pending()
        sendRequestHandler?(identifier, server, request, seal)
        return .success(Task {
            try await promise.asyncValue()
        })
    }

    /// Answers with the JSON a server would have returned. The typed `sendEphemeral` overloads all
    /// funnel through this one, so callers still go through the real response mapping.
    var sendEphemeralHandler: ((Server, WebhookRequest) -> Any)?

    override func sendEphemeral<ResponseType>(
        server: Server,
        request: WebhookRequest,
        overrideURL: URL? = nil
    ) -> Promise<ResponseType> {
        guard let sendEphemeralHandler else {
            return .init(error: FakeWebhookManagerError.noEphemeralHandler)
        }

        guard let response = sendEphemeralHandler(server, request) as? ResponseType else {
            return .init(error: FakeWebhookManagerError.ephemeralResponseTypeMismatch)
        }

        return .value(response)
    }
}

enum FakeWebhookManagerError: Error {
    /// No handler was set, so the test did not expect an ephemeral request at all.
    case noEphemeralHandler
    /// A handler answered, but with something other than the type the caller asked to decode.
    case ephemeralResponseTypeMismatch
}
