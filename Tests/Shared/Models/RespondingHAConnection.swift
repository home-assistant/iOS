import Foundation
import HAKit
import HAKit_Mocks
@testable import Shared

/// A connection that answers each request the moment it is sent, from `respond`; a nil answer
/// leaves the request pending forever, the way a server that stopped answering does.
///
/// `HAMockConnection` only queues requests and is not open for subclassing, so tests that drive
/// code end to end without answering each request by hand need a connection of their own.
final class RespondingHAConnection: HAConnection {
    typealias Responder = (HARequest) -> Result<HAData, HAError>?

    weak var delegate: HAConnectionDelegate?
    var configuration = HAConnectionConfiguration(
        connectionInfo: { nil },
        fetchAuthToken: { completion in completion(.success("token")) }
    )
    var state: HAConnectionState = .ready(version: "1.0-stub")
    lazy var caches: HACachesContainer = .init(connection: self)
    var callbackQueue: DispatchQueue = .main

    private let lock = NSLock()
    private var sentRequests: [HARequest] = []
    private var cancelledCount = 0
    private let respond: Responder

    init(respond: @escaping Responder) {
        self.respond = respond
    }

    /// The command or REST path of every request sent so far, in order.
    var sentCommands: [String] {
        lock.lock()
        defer { lock.unlock() }
        return sentRequests.map(\.type.command)
    }

    /// The data of every request sent so far, in order.
    var sentData: [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }
        return sentRequests.map(\.data)
    }

    /// How many requests were cancelled.
    var cancellations: Int {
        lock.lock()
        defer { lock.unlock() }
        return cancelledCount
    }

    func connect() {}

    func disconnect() {}

    @discardableResult
    func send(_ request: HARequest, completion: @escaping RequestCompletion) -> HACancellable {
        lock.lock()
        sentRequests.append(request)
        lock.unlock()
        if let result = respond(request) {
            completion(result)
        }
        return HAMockCancellable { [weak self] in
            guard let self else { return }
            lock.lock()
            cancelledCount += 1
            lock.unlock()
        }
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
        HAMockCancellable {}
    }

    @discardableResult
    func subscribe(
        to request: HARequest,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable {
        HAMockCancellable {}
    }

    @discardableResult
    func subscribe<T>(
        to request: HATypedSubscription<T>,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        HAMockCancellable {}
    }

    @discardableResult
    func subscribe<T>(
        to request: HATypedSubscription<T>,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        HAMockCancellable {}
    }
}
