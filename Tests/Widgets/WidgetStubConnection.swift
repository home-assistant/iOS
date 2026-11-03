import Foundation
import HAKit
import HAKit_Mocks
@testable import Shared

/// A connection that answers every request the moment it is sent, from `respond`.
///
/// `HAMockConnection` only queues requests and is not open for subclassing, so tests that drive a
/// provider end to end without answering each request by hand need a connection of their own. The
/// answer arrives synchronously, which every `withCheckedContinuation` wrapper around `send`
/// tolerates, so nothing waits on another thread.
final class WidgetStubConnection: HAConnection {
    typealias Responder = (HARequest) -> Result<HAData, HAError>

    weak var delegate: HAConnectionDelegate?
    var configuration = HAConnectionConfiguration(
        connectionInfo: { nil },
        fetchAuthToken: { completion in completion(.success("token")) }
    )
    var state: HAConnectionState = .ready(version: "1.0-stub")
    lazy var caches: HACachesContainer = .init(connection: self)
    var callbackQueue: DispatchQueue = .main

    /// What a subscription delivers the moment it is made: its initial result (nil for none) and
    /// the events that follow, in order.
    typealias SubscriptionResponder = (HARequest) -> (initiated: Result<HAData, HAError>?, events: [HAData])

    private let lock = NSLock()
    private var sentRequests: [HARequest] = []
    private var subscribedRequests: [HARequest] = []
    private let respond: Responder
    private let subscriptionResponder: SubscriptionResponder

    init(
        respond: @escaping Responder,
        subscriptions: @escaping SubscriptionResponder = { _ in (nil, []) }
    ) {
        self.respond = respond
        self.subscriptionResponder = subscriptions
    }

    /// Every subscription made so far, in order.
    var subscriptions: [HARequest] {
        lock.lock()
        defer { lock.unlock() }
        return subscribedRequests
    }

    /// Every request sent so far, in order.
    var sent: [HARequest] {
        lock.lock()
        defer { lock.unlock() }
        return sentRequests
    }

    /// The command or REST path of every request sent so far.
    var sentCommands: [String] {
        sent.map(\.type.command)
    }

    func connect() {}

    func disconnect() {}

    @discardableResult
    func send(_ request: HARequest, completion: @escaping RequestCompletion) -> HACancellable {
        lock.lock()
        sentRequests.append(request)
        lock.unlock()
        completion(respond(request))
        return HAMockCancellable {}
    }

    @discardableResult
    func send<T: HADataDecodable>(
        _ request: HATypedRequest<T>,
        completion: @escaping (Swift.Result<T, HAError>) -> Void
    ) -> HACancellable {
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

    @discardableResult
    func subscribe(to request: HARequest, handler: @escaping SubscriptionHandler) -> HACancellable {
        subscribe(to: request, initiated: { _ in }, handler: handler)
    }

    @discardableResult
    func subscribe(
        to request: HARequest,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable {
        lock.lock()
        subscribedRequests.append(request)
        lock.unlock()
        let cancellable = HAMockCancellable {}
        let (result, events) = subscriptionResponder(request)
        if let result {
            initiated(result)
        }
        for event in events {
            handler(cancellable, event)
        }
        return cancellable
    }

    @discardableResult
    func subscribe<T>(
        to request: HATypedSubscription<T>,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        subscribe(to: request, initiated: { _ in }, handler: handler)
    }

    @discardableResult
    func subscribe<T>(
        to request: HATypedSubscription<T>,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        subscribe(to: request.request, initiated: initiated) { cancellable, data in
            if let value = try? T(data: data) {
                handler(cancellable, value)
            }
        }
    }
}

/// A failure for a request a test did not expect to be sent.
let widgetStubUnexpected: HAError = .internal(debugDescription: "unexpected request")
