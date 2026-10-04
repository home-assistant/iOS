import Foundation
import HAKit

/// An `HAConnection` that answers every typed request synchronously from `responses`, keyed by the
/// request's command (`states`, `config/device_registry/list`, ...). A command without a canned
/// response fails, which is how tests drive the failure paths.
final class CannedResponseHAConnection: HAConnection {
    weak var delegate: HAConnectionDelegate?
    var configuration = HAConnectionConfiguration(
        connectionInfo: { nil },
        fetchAuthToken: { completion in completion(.success("token")) }
    )
    var state: HAConnectionState = .disconnected(reason: .disconnected)
    lazy var caches: HACachesContainer = .init(connection: self)
    var callbackQueue: DispatchQueue = .main

    private let lock = NSLock()
    private var underlyingResponses: [String: HAData] = [:]
    private var underlyingSentCommands: [String] = []

    var responses: [String: HAData] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return underlyingResponses
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            underlyingResponses = newValue
        }
    }

    var sentCommands: [String] {
        lock.lock()
        defer { lock.unlock() }
        return underlyingSentCommands
    }

    private func record(_ request: HARequest) -> HAData? {
        lock.lock()
        defer { lock.unlock() }
        underlyingSentCommands.append(request.type.command)
        return underlyingResponses[request.type.command]
    }

    func connect() {}

    func disconnect() {}

    @discardableResult
    func send(
        _ request: HARequest,
        completion: @escaping RequestCompletion
    ) -> HACancellable {
        if let data = record(request) {
            completion(.success(data))
        } else {
            completion(.failure(.internal(debugDescription: "No canned response")))
        }
        return HANoopCancellable()
    }

    @discardableResult
    func send<T>(
        _ request: HATypedRequest<T>,
        completion: @escaping (Swift.Result<T, HAError>) -> Void
    ) -> HACancellable where T: HADataDecodable {
        guard let data = record(request.request) else {
            completion(.failure(.internal(debugDescription: "No canned response")))
            return HANoopCancellable()
        }

        do {
            try completion(.success(T(data: data)))
        } catch {
            completion(.failure(.underlying(error as NSError)))
        }
        return HANoopCancellable()
    }

    @discardableResult
    func subscribe(
        to request: HARequest,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable {
        _ = record(request)
        return HANoopCancellable()
    }

    @discardableResult
    func subscribe(
        to request: HARequest,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable {
        _ = record(request)
        initiated(.failure(.internal(debugDescription: "Subscriptions not supported")))
        return HANoopCancellable()
    }

    @discardableResult
    func subscribe<T>(
        to request: HATypedSubscription<T>,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        _ = record(request.request)
        return HANoopCancellable()
    }

    @discardableResult
    func subscribe<T>(
        to request: HATypedSubscription<T>,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        _ = record(request.request)
        initiated(.failure(.internal(debugDescription: "Subscriptions not supported")))
        return HANoopCancellable()
    }
}
