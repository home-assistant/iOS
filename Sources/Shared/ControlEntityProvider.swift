import Foundation
import GRDB
import HAKit
import SwiftUI

public final class ControlEntityProvider {
    public enum States: String {
        case open
        case opening
        case close
        case closing
        case on
        case off
    }

    public struct State {
        public let value: String
        public let unitOfMeasurement: String?
        public let domainState: Domain.State?
        /// The raw, lowercased entity state. `value` is formatted for display (precision, unit,
        /// device-class wording), so anything that keys off the state itself — the frontend's icon
        /// color palette — needs the original.
        public let rawState: String
        /// The raw `device_class` attribute, which that palette also keys off.
        public let deviceClass: String?
        /// The light's own color, already contrast-adjusted, when it reports one.
        public let liveColor: Color?
        /// For a `group`, the domain all of its members share, whose palette the group borrows.
        public let groupMemberDomain: String?

        public init(
            value: String,
            unitOfMeasurement: String?,
            domainState: Domain.State?,
            rawState: String = "",
            deviceClass: String? = nil,
            liveColor: Color? = nil,
            groupMemberDomain: String? = nil
        ) {
            self.value = value
            self.unitOfMeasurement = unitOfMeasurement
            self.domainState = domainState
            self.rawState = rawState
            self.deviceClass = deviceClass
            self.liveColor = liveColor
            self.groupMemberDomain = groupMemberDomain
        }
    }

    public let domains: [Domain]

    public init(domains: [Domain]) {
        self.domains = domains
    }

    public func currentState(serverId: String, entityId: String) async throws -> String? {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }),
              let connection = Current.api(for: server)?.connection else {
            return nil
        }
        let state: String? = await withCheckedContinuation { continuation in
            connection.send(.init(
                type: .rest(.get, "states/\(entityId)")
            )) { result in
                switch result {
                case let .success(data):
                    let state: String? = data.decode("state", fallback: nil)
                    continuation.resume(returning: state)
                case let .failure(error):
                    Current.Log.error("Failed to get \(entityId) state for ControlEntityProvider: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }

        return state
    }

    public func getEntities(matching string: String? = nil) -> [(Server, [HAAppEntity])] {
        var entitiesPerServer: [(Server, [HAAppEntity])] = []
        for server in Current.servers.all.sorted(by: { $0.info.name < $1.info.name }) {
            do {
                var entities: [HAAppEntity] = try Current.database().read { db in
                    if domains.isEmpty {
                        try HAAppEntity
                            .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
                            .fetchAll(db)
                    } else {
                        try HAAppEntity
                            .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
                            .filter(domains.map(\.rawValue).contains(Column(DatabaseTables.AppEntity.domain.rawValue)))
                            .fetchAll(db)
                    }
                }
                if let string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let index = EntityFuzzySearchIndex(entities: entities, serverId: server.identifier.rawValue)
                    entities = index.search(string)
                }
                entitiesPerServer.append((server, entities))
            } catch {
                Current.Log.error("Failed to load entities from database: \(error.localizedDescription)")
            }
        }

        return entitiesPerServer
    }

    /// Fetches the raw `attributes` dictionary for an entity over the REST `/states` endpoint. Used by
    /// the widgets' entity source to list an entity's attributes and read the chosen one's value.
    public func attributes(server: Server, entityId: String) async -> [String: Any]? {
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available to fetch attributes data")
            return nil
        }

        let result = await withCheckedContinuation { continuation in
            connection.send(.init(
                type: .rest(.get, "states/\(entityId)"),
                shouldRetry: true
            )) { result in
                continuation.resume(returning: result)
            }
        }

        guard let data = try? result.get() else {
            if case let .failure(error) = result {
                Current.Log.error("Failed to get attributes: \(error)")
            }
            return nil
        }

        guard case let .dictionary(state) = data else {
            Current.Log.error("Failed to get attributes: bad response data")
            return nil
        }

        return state["attributes"] as? [String: Any]
    }

    /// Fetches an entity's raw state string and attributes in one REST `/states` call, with no
    /// precision or capitalization applied. Callers that do their own formatting (the complication
    /// render pipeline, which owns precision + unit) need the untouched value.
    public func rawState(server: Server, entityId: String) async -> (state: String, attributes: [String: Any])? {
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available to fetch raw state data")
            return nil
        }

        let result = await withCheckedContinuation { continuation in
            connection.send(.init(
                type: .rest(.get, "states/\(entityId)"),
                shouldRetry: true
            )) { result in
                continuation.resume(returning: result)
            }
        }

        guard let data = try? result.get() else {
            if case let .failure(error) = result {
                Current.Log.error("Failed to get raw state: \(error)")
            }
            return nil
        }

        guard case let .dictionary(json) = data, let state = json["state"] as? String else {
            Current.Log.error("Failed to get raw state: bad response data")
            return nil
        }

        return (state, json["attributes"] as? [String: Any] ?? [:])
    }

    public func state(server: Server, entityId: String) async -> State? {
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available to fetch state data")
            return nil
        }

        guard let data = await sendStateRequest(connection: connection, entityId: entityId) else {
            return nil
        }

        guard case let .dictionary(state) = data else {
            Current.Log.error("Failed to get state bad response data")
            return nil
        }

        return makeState(
            server: server,
            entityId: entityId,
            rawStateValue: (state["state"] as? String) ?? "N/A",
            attributes: state["attributes"] as? [String: Any]
        )
    }

    /// Fetches several entities' states from one server in a single `subscribe_entities` round trip,
    /// rather than one REST `/states` request each. The subscription's first event carries every
    /// requested entity, so it is cancelled as soon as that arrives.
    ///
    /// Returns `nil` when the batch can't be made — a server too old for it, no API, a websocket that
    /// can't deliver it in time, or a refused subscription — so the caller can fall back to
    /// `state(server:entityId:)`. An entity the server doesn't have is left out, as a REST request for
    /// it would have failed.
    public func states(server: Server, entityIds: [String]) async -> [String: State]? {
        guard !entityIds.isEmpty else { return [:] }

        guard server.info.version >= .canSubscribeEntitiesByIds else {
            return nil
        }

        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available to fetch states data")
            return nil
        }

        guard Self.canBatchStates(over: connection.state) else {
            Current.Log.info("Not batching states while the websocket is \(connection.state)")
            return nil
        }

        guard let entities = await sendStatesSubscription(connection: connection, entityIds: entityIds) else {
            return nil
        }

        var states: [String: State] = [:]
        for (entityId, entity) in entities {
            states[entityId] = makeState(
                server: server,
                entityId: entityId,
                rawStateValue: entity.state ?? "N/A",
                attributes: entity.attributes
            )
        }
        return states
    }

    /// Whether a batch sent over a websocket in this state can expect an answer in time. One waiting
    /// out HAKit's reconnect backoff, or one the server rejected, won't carry the subscription until
    /// long after a widget has had to render, while REST requests don't need the websocket at all.
    static func canBatchStates(over state: HAConnectionState) -> Bool {
        switch state {
        case .ready, .connecting, .authenticating, .disconnected(reason: .disconnected):
            return true
        case .disconnected(reason: .waitingToReconnect), .disconnected(reason: .rejected):
            return false
        }
    }

    private func makeState(
        server: Server,
        entityId: String,
        rawStateValue: String,
        attributes: [String: Any]?
    ) -> State {
        let stateValue = StatePrecision.adjustPrecision(
            serverId: server.identifier.rawValue,
            entityId: entityId,
            stateValue: rawStateValue
        ).capitalizedFirst

        return buildState(
            entityId: entityId,
            rawStateValue: rawStateValue.lowercased(),
            stateValue: stateValue,
            attributes: attributes,
            unitOfMeasurement: attributes?["unit_of_measurement"] as? String
        )
    }

    /// Sends `subscribe_entities` for `entityIds` and returns its first event's entities, honoring task
    /// cancellation the same way `sendStateRequest` does. A refused subscription resolves to `nil`.
    private func sendStatesSubscription(
        connection: HAConnection,
        entityIds: [String]
    ) async -> [String: HACompressedEntityState]? {
        typealias Entities = [String: HACompressedEntityState]
        let request = PendingRequest<Entities>(cancelsOnSettle: true)

        // A websocket that drops into a reconnect backoff, or is rejected, while the subscription is
        // out won't deliver it in time either. Giving up then leaves the caller time to fall back.
        let stateObserver = NotificationCenter.default.addObserver(
            forName: HAConnectionState.didTransitionToStateNotification,
            object: connection,
            queue: nil
        ) { _ in
            let state = connection.state
            guard !Self.canBatchStates(over: state) else { return }
            Current.Log.info("Giving up on batched states as the websocket is \(state)")
            request.finish(with: nil)
        }
        defer { NotificationCenter.default.removeObserver(stateObserver) }

        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Entities?, Never>) in
                let token = connection.subscribe(
                    to: .subscribeEntities(data: ["entity_ids": entityIds]),
                    initiated: { result in
                        if case let .failure(error) = result {
                            Current.Log.error("Failed to subscribe to entities for their states: \(error)")
                            request.finish(with: nil)
                        }
                    },
                    handler: { _, updates in
                        request.finish(with: updates.add ?? [:])
                    }
                )

                request.adopt(continuation: continuation, token: token)
            }
        } onCancel: {
            request.cancel()
        }
    }

    /// Sends the `/states/<entity>` request in a way that honors task cancellation.
    ///
    /// HAKit drops a cancelled request's completion handler without calling it, and logs-and-discards
    /// a response whose invocation is no longer active, so a bare `withCheckedContinuation` around
    /// `send` can be left unresumed forever. Callers that bound how long they are willing to wait —
    /// the widgets fetch every tile's state against a deadline — would hang on that instead of giving
    /// up, which is worse than the slow request they were guarding against.
    private func sendStateRequest(connection: HAConnection, entityId: String) async -> HAData? {
        let request = PendingRequest<HAData>(cancelsOnSettle: false)

        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<HAData?, Never>) in
                let token = connection.send(.init(
                    type: .rest(.get, "states/\(entityId)"),
                    shouldRetry: true
                )) { result in
                    switch result {
                    case let .success(data):
                        request.finish(with: data)
                    case let .failure(error):
                        Current.Log.error("Failed to get state: \(error)")
                        request.finish(with: nil)
                    }
                }

                request.adopt(continuation: continuation, token: token)
            }
        } onCancel: {
            request.cancel()
        }
    }

    /// Shared one-shot ownership of a request's continuation, so exactly one of HAKit's handlers and
    /// the cancellation handler resumes it — whichever gets there first.
    private final class PendingRequest<Value>: @unchecked Sendable {
        private let lock = NSLock()
        /// Whether finishing also cancels the HAKit request. A single request is done once it
        /// answers, but a subscription keeps streaming, and a refused one keeps being retried, until
        /// it is cancelled.
        private let cancelsOnSettle: Bool
        private var continuation: CheckedContinuation<Value?, Never>?
        private var token: HACancellable?
        /// Whether the request has already been settled, by completing or by being cancelled.
        /// `earlyResult` is only meaningful once this is true, which is what lets it stay a single
        /// optional: a settled request with no result is a cancelled or failed one.
        private var isSettled = false
        /// A result that landed before `adopt` ran, which `send` is free to do by calling back
        /// synchronously.
        private var earlyResult: Value?

        init(cancelsOnSettle: Bool) {
            self.cancelsOnSettle = cancelsOnSettle
        }

        /// Takes ownership of the continuation and the in-flight request, resuming straight away if
        /// the request already settled while it was being handed over.
        func adopt(continuation: CheckedContinuation<Value?, Never>, token: HACancellable) {
            lock.lock()
            guard !isSettled else {
                let result = earlyResult
                lock.unlock()
                token.cancel()
                continuation.resume(returning: result)
                return
            }
            self.continuation = continuation
            self.token = token
            lock.unlock()
        }

        func finish(with value: Value?) {
            lock.lock()
            guard !isSettled else {
                lock.unlock()
                return
            }
            isSettled = true
            guard let continuation else {
                earlyResult = value
                lock.unlock()
                return
            }
            let token = token
            self.continuation = nil
            self.token = nil
            lock.unlock()
            if cancelsOnSettle {
                token?.cancel()
            }
            continuation.resume(returning: value)
        }

        func cancel() {
            lock.lock()
            guard !isSettled else {
                lock.unlock()
                return
            }
            isSettled = true
            let continuation = continuation
            let token = token
            self.continuation = nil
            self.token = nil
            lock.unlock()
            token?.cancel()
            continuation?.resume(returning: nil)
        }
    }

    private func buildState(
        entityId: String,
        rawStateValue: String,
        stateValue: String,
        attributes: [String: Any]?,
        unitOfMeasurement: String?
    ) -> State {
        let domain = Domain(entityId: entityId)
        let domainState = Domain.State(rawValue: stateValue.lowercased())
        let rawDomain = entityId.components(separatedBy: ".").first ?? ""
        let colorAttributes = EntityColorAttributesParser.parse(from: attributes)

        // The color is left to the view layer to resolve from these ingredients rather than baked
        // in here: the widgets cache this state, and a resolved color would be flattened to a
        // single appearance instead of following the current color scheme.
        let liveColor = EntityIconColorProvider.liveColor(
            domain: rawDomain,
            rgbColor: colorAttributes.rgbColor,
            hsColor: colorAttributes.hsColor
        )
        let deviceClass = attributes?["device_class"] as? String
        let groupMemberDomain = rawDomain == Domain.group.rawValue
            ? EntityIconColorProvider.groupMemberDomain(attributes: attributes)
            : nil

        var value = stateValue
        var unit = unitOfMeasurement
        if let deviceClass = deviceClass.flatMap(DeviceClass.init(rawValue:)),
           let domainState,
           unitOfMeasurement == nil,
           let stateForDeviceClass = domain?.stateForDeviceClass(deviceClass, state: domainState) {
            value = stateForDeviceClass
            unit = nil
        }

        return .init(
            value: value,
            unitOfMeasurement: unit,
            domainState: domainState,
            rawState: rawStateValue,
            deviceClass: deviceClass,
            liveColor: liveColor,
            groupMemberDomain: groupMemberDomain
        )
    }
}

public extension ControlEntityProvider {
    /// The same entities, minus the servers the user has opted out of exposing to Siri.
    ///
    /// Siri, Spotlight and the Shortcuts app read through this. Widgets, controls and the reminders
    /// sync keep using `getEntities`: the setting is about what is offered to Siri, not about
    /// hiding a server from the rest of the app.
    func getEntitiesExposedToSiri(matching string: String? = nil) -> [(Server, [HAAppEntity])] {
        let hidden = SiriServerExposure.hiddenServerIds()
        guard !hidden.isEmpty else {
            return getEntities(matching: string)
        }
        return getEntities(matching: string).filter { !hidden.contains($0.0.identifier.rawValue) }
    }
}
