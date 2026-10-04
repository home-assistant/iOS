import Foundation
import HAKit

/// An `HAConnection` that answers every request from a table keyed by the request's command (the
/// WebSocket command, or the REST path after `api/`), so tests can drive the code that talks to the
/// server without a socket or polling for pending requests.
///
/// Unscripted commands fail. Answers are delivered synchronously by default, or from a background
/// queue after `send` has returned when `respondsAsynchronously` is set, which exercises the paths
/// that hand a continuation over before the answer lands.
final class MagicItemTestConnection: HAConnection {
    weak var delegate: HAConnectionDelegate?
    var configuration = HAConnectionConfiguration(
        connectionInfo: { nil },
        fetchAuthToken: { completion in completion(.success("token")) }
    )
    var state: HAConnectionState = .disconnected(reason: .disconnected)
    lazy var caches: HACachesContainer = .init(connection: self)
    var callbackQueue: DispatchQueue = .main

    var responses = [String: Swift.Result<HAData, HAError>]()
    var respondsAsynchronously = false

    private let lock = NSLock()
    private var recordedRequests = [HARequest]()

    var sentRequests: [HARequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    func connect() {}

    func disconnect() {}

    private func record(_ request: HARequest) {
        lock.lock()
        recordedRequests.append(request)
        lock.unlock()
    }

    private func response(for request: HARequest) -> Swift.Result<HAData, HAError> {
        responses[request.type.command]
            ?? .failure(.internal(debugDescription: "Unscripted command \(request.type.command)"))
    }

    private func deliver(_ body: @escaping () -> Void) {
        if respondsAsynchronously {
            DispatchQueue.global().async(execute: body)
        } else {
            body()
        }
    }

    @discardableResult
    func send(
        _ request: HARequest,
        completion: @escaping RequestCompletion
    ) -> HACancellable {
        record(request)
        let result = response(for: request)
        deliver { completion(result) }
        return HANoopCancellable()
    }

    @discardableResult
    func send<T>(
        _ request: HATypedRequest<T>,
        completion: @escaping (Swift.Result<T, HAError>) -> Void
    ) -> HACancellable where T: HADataDecodable {
        record(request.request)
        let typedResult: Swift.Result<T, HAError>
        switch response(for: request.request) {
        case let .success(data):
            do {
                typedResult = try .success(T(data: data))
            } catch {
                typedResult = .failure(.underlying(error as NSError))
            }
        case let .failure(error):
            typedResult = .failure(error)
        }
        deliver { completion(typedResult) }
        return HANoopCancellable()
    }

    @discardableResult
    func subscribe(
        to request: HARequest,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable {
        record(request)
        return HANoopCancellable()
    }

    @discardableResult
    func subscribe(
        to request: HARequest,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable {
        record(request)
        initiated(.failure(.internal(debugDescription: "Subscriptions not scripted")))
        return HANoopCancellable()
    }

    @discardableResult
    func subscribe<T>(
        to request: HATypedSubscription<T>,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        record(request.request)
        return HANoopCancellable()
    }

    @discardableResult
    func subscribe<T>(
        to request: HATypedSubscription<T>,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        record(request.request)
        initiated(.failure(.internal(debugDescription: "Subscriptions not scripted")))
        return HANoopCancellable()
    }
}
