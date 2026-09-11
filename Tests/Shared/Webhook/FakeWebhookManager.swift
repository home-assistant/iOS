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
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                promise.pipe { result in
                    switch result {
                    case .fulfilled:
                        continuation.resume()
                    case let .rejected(error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        })
    }
}
