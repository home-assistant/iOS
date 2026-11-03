import Foundation
import HAKit
import HAKit_Mocks

/// A connection that answers every request synchronously from `answer`, on whatever thread the
/// request is sent from. Unlike polling `HAMockConnection.pendingRequests` from the main actor,
/// this can't race with the API's background sends, so no request is ever left unanswered.
final class RemindersSyncAnsweringConnection: HAConnection {
    private let lock = NSLock()
    private var answered: [HARequest] = []
    private let answer: (HARequest) -> Result<HAData, HAError>

    init(answer: @escaping (HARequest) -> Result<HAData, HAError>) {
        self.answer = answer
    }

    /// Every request received so far, in the order it was sent.
    var requests: [HARequest] {
        lock.withLock { answered }
    }

    weak var delegate: HAConnectionDelegate?
    var configuration: HAConnectionConfiguration = .fake
    var state: HAConnectionState { .ready(version: "test") }
    lazy var caches: HACachesContainer = .init(connection: self)
    var callbackQueue: DispatchQueue = .main

    func connect() {}
    func disconnect() {}

    func send(_ request: HARequest, completion: @escaping RequestCompletion) -> HACancellable {
        lock.withLock { answered.append(request) }
        completion(answer(request))
        return HAMockCancellable {}
    }

    func send<T>(_ request: HATypedRequest<T>, completion: @escaping (Result<T, HAError>) -> Void) -> HACancellable {
        send(request.request) { result in
            switch result {
            case let .success(data):
                do {
                    try completion(.success(T(data: data)))
                } catch {
                    completion(.failure(.underlying(error as NSError)))
                }
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    func subscribe(to request: HARequest, handler: @escaping SubscriptionHandler) -> HACancellable {
        HAMockCancellable {}
    }

    func subscribe(
        to request: HARequest,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable {
        HAMockCancellable {}
    }

    func subscribe<T>(
        to request: HATypedSubscription<T>,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        HAMockCancellable {}
    }

    func subscribe<T>(
        to request: HATypedSubscription<T>,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        HAMockCancellable {}
    }
}
