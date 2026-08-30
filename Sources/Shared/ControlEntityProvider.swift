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

        let rawStateValue = (state["state"] as? String) ?? "N/A"
        var stateValue = StatePrecision.adjustPrecision(
            serverId: server.identifier.rawValue,
            entityId: entityId,
            stateValue: rawStateValue
        )
        stateValue = stateValue.capitalizedFirst

        let attributes = state["attributes"] as? [String: Any]
        let unitOfMeasurement = attributes?["unit_of_measurement"] as? String

        return buildState(
            entityId: entityId,
            rawStateValue: rawStateValue.lowercased(),
            stateValue: stateValue,
            attributes: attributes,
            unitOfMeasurement: unitOfMeasurement
        )
    }

    /// Sends the `/states/<entity>` request in a way that honors task cancellation.
    ///
    /// HAKit drops a cancelled request's completion handler without calling it, and logs-and-discards
    /// a response whose invocation is no longer active, so a bare `withCheckedContinuation` around
    /// `send` can be left unresumed forever. Callers that bound how long they are willing to wait —
    /// the widgets fetch every tile's state against a deadline — would hang on that instead of giving
    /// up, which is worse than the slow request they were guarding against.
    private func sendStateRequest(connection: HAConnection, entityId: String) async -> HAData? {
        let request = PendingStateRequest()

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

    /// Shared one-shot ownership of a state request's continuation, so exactly one of HAKit's
    /// completion handler and the cancellation handler resumes it — whichever gets there first.
    private final class PendingStateRequest: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<HAData?, Never>?
        private var token: HACancellable?
        private var isSettled = false
        /// A result that landed before `adopt` ran, which `send` is free to do by calling back
        /// synchronously.
        private var earlyResult: HAData??

        /// Takes ownership of the continuation and the in-flight request, resuming straight away if
        /// the request already settled while it was being handed over.
        func adopt(continuation: CheckedContinuation<HAData?, Never>, token: HACancellable) {
            lock.lock()
            guard !isSettled else {
                let result = earlyResult ?? nil
                lock.unlock()
                token.cancel()
                continuation.resume(returning: result)
                return
            }
            self.continuation = continuation
            self.token = token
            lock.unlock()
        }

        func finish(with data: HAData?) {
            lock.lock()
            guard !isSettled else {
                lock.unlock()
                return
            }
            isSettled = true
            guard let continuation else {
                earlyResult = .some(data)
                lock.unlock()
                return
            }
            self.continuation = nil
            token = nil
            lock.unlock()
            continuation.resume(returning: data)
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
