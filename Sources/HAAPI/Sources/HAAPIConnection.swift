import Foundation

/// An actor-based Home Assistant websocket API client built on `URLSessionWebSocketTask`.
///
/// Lifecycle is caller-driven: call `connect()` when the app is active and `disconnect()` when
/// it resigns — on watchOS the system kills background sockets, so the owner decides when a
/// connection should exist. While connected the actor maintains the authenticated session,
/// correlates command ids, routes subscription events, sends protocol-level heartbeats, and
/// transparently reconnects with backoff — re-sending pending requests and re-issuing active
/// subscriptions on the new session.
public actor HAAPIConnection {
    let configuration: HAAPIConfiguration
    let transportFactory: any HAAPITransportFactory

    var transport: (any HAAPITransport)?
    var supervisorTask: Task<Void, Never>?
    var heartbeatTask: Task<Void, Never>?
    var reconnectAttempt = 0
    var nextCommandID = 1

    var requestRecords: [UUID: PendingRequest] = [:]
    var requestTokensByServerID: [Int: UUID] = [:]
    var subscriptionRecords: [UUID: SubscriptionRecord] = [:]
    var subscriptionTokensByServerID: [Int: UUID] = [:]

    private(set) var stateValue: HAAPIConnectionState = .disconnected(reason: .initial)
    private var stateObservers: [UUID: AsyncStream<HAAPIConnectionState>.Continuation] = [:]

    public init(
        configuration: HAAPIConfiguration,
        transportFactory: any HAAPITransportFactory = HAAPIURLSessionTransportFactory()
    ) {
        self.configuration = configuration
        self.transportFactory = transportFactory
    }

    public var state: HAAPIConnectionState { stateValue }

    /// A fresh stream per call; yields the current state first, then every change.
    public func states() -> AsyncStream<HAAPIConnectionState> {
        AsyncStream { continuation in
            let id = UUID()
            continuation.yield(stateValue)
            stateObservers[id] = continuation
            continuation.onTermination = { _ in
                Task { await self.removeStateObserver(id) }
            }
        }
    }

    /// Starts the connect/auth/reconnect loop. Idempotent while a loop is running.
    public func connect() {
        guard supervisorTask == nil else { return }
        reconnectAttempt = 0
        supervisorTask = Task { await runSupervisor() }
    }

    /// Stops the loop, closes the socket, fails pending requests and finishes subscription
    /// streams with `HAAPIError.cancelled`.
    public func disconnect() {
        supervisorTask?.cancel()
        supervisorTask = nil
        stopHeartbeat()
        transport?.close(code: .normalClosure)
        transport = nil
        failAllRequests(with: .cancelled)
        finishAllSubscriptions(throwing: HAAPIError.cancelled)
        setState(.disconnected(reason: .requested))
    }

    func setState(_ newState: HAAPIConnectionState) {
        guard newState != stateValue else { return }
        stateValue = newState
        for continuation in stateObservers.values {
            continuation.yield(newState)
        }
    }

    func takeNextCommandID() -> Int {
        defer { nextCommandID += 1 }
        return nextCommandID
    }

    func failAllRequests(with error: HAAPIError) {
        let records = requestRecords
        requestRecords = [:]
        requestTokensByServerID = [:]
        for record in records.values {
            record.continuation.resume(throwing: error)
        }
    }

    func finishAllSubscriptions(throwing error: any Error) {
        let records = subscriptionRecords
        subscriptionRecords = [:]
        subscriptionTokensByServerID = [:]
        for record in records.values {
            record.finish(error)
        }
    }

    private func removeStateObserver(_ id: UUID) {
        stateObservers[id] = nil
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        // HA mixes date formats: ISO8601 with fractional seconds (get_states) and epoch seconds
        // (compressed subscribe_entities payloads).
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let seconds = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: seconds)
            }
            let string = try container.decode(String.self)
            if let date = try? Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
                return date
            }
            if let date = try? Date(string, strategy: .iso8601) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date format: \(string)"
            )
        }
        return decoder
    }

    static func parseEnvelope(_ frame: HAAPITransportMessage) throws -> (Data, ServerEnvelope) {
        let data: Data = switch frame {
        case let .text(text): Data(text.utf8)
        case let .data(data): data
        }
        do {
            return try (data, makeDecoder().decode(ServerEnvelope.self, from: data))
        } catch {
            throw HAAPIError.decoding(command: "<frame>", description: String(describing: error))
        }
    }
}
