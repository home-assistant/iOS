import CoreLocation
import Foundation
import HAKit
import PromiseKit

public struct SensorObserverUpdate {
    public let sensors: Guarantee<[WebhookSensor]>
    public let on: Date

    init(sensors: Guarantee<[WebhookSensor]>) {
        self.sensors = sensors
        self.on = Current.date()
    }
}

public enum SensorContainerUpdateReason {
    /// - Parameter changedUniqueIDs: the sensors whose enablement changed, which need re-registering
    ///   so Home Assistant enables or disables the matching entities. Empty when the change didn't
    ///   come from a specific set of sensors.
    case settingsChange(changedUniqueIDs: [String])
    case signal
}

public protocol SensorObserver: AnyObject {
    func sensorContainer(
        _ container: SensorContainer,
        didUpdate update: SensorObserverUpdate
    )
    func sensorContainer(
        _ container: SensorContainer,
        didSignalForUpdateBecause reason: SensorContainerUpdateReason,
        lastUpdate: SensorObserverUpdate?
    )
}

public struct SensorResponse {
    /// The sensors that require update
    public let sensors: [WebhookSensor]

    fileprivate init(sensors: [WebhookSensor]) {
        self.sensors = sensors
    }
}

public class SensorContainer {
    private let providers = HAProtected<[SensorProvider.Type]>(value: [])
    private let observers = HAProtected<NSHashTable<AnyObject>>(value: .init(options: .weakMemory))
    private let providerDependencies: SensorProviderDependencies
    private let enablement = SensorEnablementStore()

    init() {
        self.providerDependencies = SensorProviderDependencies()
        providerDependencies.updateSignalHandler = { [weak self] type in
            self?.updateSignaled(from: type)
        }
    }

    public func register(provider: SensorProvider.Type) {
        providers.mutate { $0.append(provider) }
    }

    public func register(observer: SensorObserver) {
        observers.mutate { $0.add(observer) }

        if let lastUpdate = lastUpdate.read({ $0 }) {
            observer.sensorContainer(self, didUpdate: lastUpdate)
        }
    }

    public func unregister(observer: SensorObserver) {
        observers.mutate { $0.remove(observer) }
    }

    public func isEnabled(sensor: WebhookSensor) -> Bool {
        guard let id = sensor.UniqueID else { return false }
        return isEnabled(uniqueID: id)
    }

    public func isEnabled(uniqueID: String) -> Bool {
        enablement.isEnabled(uniqueID: uniqueID)
    }

    public func isAllowedToSend(sensor: WebhookSensor, for server: Server) -> Bool {
        guard isEnabled(sensor: sensor) else { return false }

        switch server.info.setting(for: .sensorPrivacy) {
        case .all: return true
        case .none: return false
        }
    }

    public func setEnabled(_ value: Bool, for sensor: WebhookSensor) {
        guard let id = sensor.UniqueID else { return }
        setEnabled(value, forUniqueID: id)
    }

    public func setEnabled(_ value: Bool, forUniqueID id: String) {
        setEnabled(value, forUniqueIDs: [id])
    }

    /// Bulk variant of `setEnabled(_:forUniqueID:)`, so changing many sensors at once signals
    /// observers a single time instead of once per sensor.
    public func setEnabled(_ value: Bool, forUniqueIDs ids: [String]) {
        // `filter` rather than a short-circuiting reduce, so every ID is actually written.
        let changed = ids.filter { enablement.setEnabled(value, forUniqueID: $0) }
        guard !changed.isEmpty else { return }
        notifySignal(reason: .settingsChange(changedUniqueIDs: changed))
    }

    /// Starts a first-time install with nothing enabled. Every sensor is opt-in, so an install that
    /// has just been set up reports only what the user switches on.
    public func resetSensorsForFirstRun() {
        guard enablement.resetForFirstRun() else { return }
        notifySignal(reason: .settingsChange(changedUniqueIDs: []))
    }

    private let lastUpdate = HAProtected<SensorObserverUpdate?>(value: nil)

    private func currentObservers() -> [SensorObserver] {
        observers.read { $0.allObjects.compactMap { $0 as? SensorObserver } }
    }

    private func setLastUpdate(_ update: SensorObserverUpdate) {
        lastUpdate.mutate { $0 = update }
        for observer in currentObservers() {
            observer.sensorContainer(self, didUpdate: update)
        }
    }

    /// One provider's sensors together with their place in the order values were read in.
    ///
    /// A run only finishes once its *slowest* provider has, which can be seconds after a fast
    /// provider read its value — long enough for a second run to start, read a newer value and
    /// send it first. Carrying the read order is what lets the older values be recognised as such
    /// when the slow run finally gets to send.
    private struct SensorBatch {
        let sensors: [WebhookSensor]
        let readOrder: UInt64
    }

    /// A single sensor value, and where the read that produced it sits in `readOrdering`.
    private struct ReadSensor {
        var sensor: WebhookSensor
        var readOrder: UInt64
    }

    private struct LastSentSensors {
        private var value = [String: ReadSensor]()

        var sensors: AnyCollection<WebhookSensor> {
            AnyCollection(value.values.map(\.sensor))
        }

        mutating func combine(with batches: [SensorBatch], ignoringExisting: Bool) {
            for batch in batches {
                for sensor in batch.sensors {
                    guard let uniqueID = sensor.UniqueID else { continue }

                    if let existing = value[uniqueID] {
                        guard !ignoringExisting else { continue }
                        // Runs overlap and don't finish in the order they started, so a value read
                        // earlier can arrive later. Showing it would blank what the user can see
                        // in sensor settings just as it does the entity in Home Assistant.
                        guard batch.readOrder > existing.readOrder else { continue }
                    }

                    value[uniqueID] = ReadSensor(sensor: sensor, readOrder: batch.readOrder)
                }
            }
        }
    }

    private var lastSentSensors: HAProtected<LastSentSensors> = .init(value: .init())

    /// Numbers each value as it is read, so two of them can be put in order.
    ///
    /// A clock can't do this job: overlapping runs are milliseconds apart, and `Date` moves
    /// backwards whenever the system clock is corrected, which would make a stale value look new.
    private let readOrdering = HAProtected<UInt64>(value: 0)

    /// The newest value handed out for sending to each server, per sensor.
    ///
    /// Home Assistant takes whatever arrives last as the current state, so a run that read a value
    /// before another run did must not be allowed to send it afterwards — that's how a Focus switch
    /// ends up logged as `Work → (blank) → Work`. Kept per server because a value that reached one
    /// server hasn't necessarily reached the others.
    ///
    /// Only state updates take part: registration describes which sensors exist rather than what
    /// they read, so it neither consults nor adds to this.
    private let lastDispatchedReads = HAProtected<[Identifier<Server>: [String: ReadSensor]]>(value: [:])

    func sensors(
        reason: SensorProviderRequest.Reason,
        limitedTo: [SensorProvider.Type]? = nil,
        location: CLLocation? = nil,
        server: Server
    ) -> Guarantee<SensorResponse> {
        let request = SensorProviderRequest(
            reason: reason,
            dependencies: providerDependencies,
            location: location,
            serverVersion: server.info.version
        )

        let generatedBatches = firstly {
            let promises = providers.read { $0 }
                .filter { providerType in
                    if let limitedTo {
                        return limitedTo.contains(where: { ObjectIdentifier($0) == ObjectIdentifier(providerType) })
                    } else {
                        return true
                    }
                }
                .map { providerType in providerType.init(request: request) }
                .map { [readOrdering] provider in
                    provider.sensors().map { sensors in
                        // Numbered as this provider resolves rather than when the run started: a
                        // provider that reads late in a slow run really did read the newer value,
                        // and one that read early in it really didn't.
                        let readOrder = readOrdering.mutate { (next: inout UInt64) -> UInt64 in
                            next += 1
                            return next
                        }
                        return (SensorBatch(sensors: sensors, readOrder: readOrder), provider)
                    }
                }

            return when(resolved: promises)
        }.map { (batches: [Result<(SensorBatch, SensorProvider)>]) -> [SensorBatch] in
            // now that we are done, we don't need to keep a strong reference to the provider instance anymore
            batches.compactMap { (result: Result<(SensorBatch, SensorProvider)>) -> SensorBatch? in
                if case let .fulfilled(value) = result {
                    return value.0
                } else {
                    return nil
                }
            }
        }.map { [weak self] batches -> [SensorBatch] in
            // A limited run only asks some of the providers, so it can't stand in for the complete
            // set the migration needs to decide the sensors whose IDs only exist at runtime.
            if limitedTo == nil {
                let uniqueIDs = batches.flatMap(\.sensors).compactMap(\.UniqueID)
                self?.enablement.seedDynamicIDsIfNeeded(from: Set(uniqueIDs))
            }
            return batches
        }

        setLastUpdate(.init(sensors: generatedBatches.map { [lastSentSensors] new in
            // doesn't store the sent values, that happens when the network request ends
            // this is just what's presented to the user, so we always have the latest version
            let ignoringExisting: Bool
            switch request.reason {
            case .registration:
                // we may want to show sensor settings, so allow even registration-focused data to populate
                // however, we don't allow any registration values to override existing ones
                ignoringExisting = true
            case .trigger:
                ignoringExisting = false
            }

            // Alphabetical, and only alphabetical: switching a sensor on must not move its row out
            // from under whoever just tapped it.
            return lastSentSensors.mutate { lastSentSensors -> AnyCollection<WebhookSensor> in
                lastSentSensors.combine(with: new, ignoringExisting: ignoringExisting)
                return lastSentSensors.sensors
            }.sorted()
        }))

        return generatedBatches.map { [weak self] batches -> SensorResponse in
            guard let self else { return SensorResponse(sensors: batches.flatMap(\.sensors)) }

            return SensorResponse(
                sensors: freshest(of: batches, for: server, reason: request.reason)
                    .map { sensor -> WebhookSensor in
                        let outgoing = self.isAllowedToSend(sensor: sensor, for: server)
                            ? sensor
                            : WebhookSensor(redacting: sensor)

                        if request.reason == .registration {
                            // Registering is the only chance to tell Home Assistant to disable the entity, rather
                            // than leave it enabled and reporting `unavailable` forever.
                            outgoing.Disabled = !self.isEnabled(sensor: sensor)
                        }

                        return outgoing
                    }
            )
        }
    }

    /// Replaces any value this run read before one already sent to this server, and records the
    /// values that do go out.
    ///
    /// Overlapping runs finish in whatever order their slowest provider allows, so "sent last" and
    /// "read last" are not the same thing — and Home Assistant only knows the former. Without this,
    /// a slow full sensor run started just before a Focus changed overwrites the fresh name a
    /// faster run reported in between, and the entity's history shows a state it was never in.
    ///
    /// The stale value is swapped for the newer one rather than dropped: this run's request
    /// replaces any still in flight for the same server, so leaving the sensor out could cancel
    /// the newer value's own delivery and lose it altogether.
    private func freshest(
        of batches: [SensorBatch],
        for server: Server,
        reason: SensorProviderRequest.Reason
    ) -> [WebhookSensor] {
        guard case .trigger = reason else {
            // Registration describes which sensors exist rather than what they read, and is the
            // only chance to create their entities — nothing here to be out of date.
            return batches.flatMap(\.sensors)
        }

        return lastDispatchedReads.mutate { allServers -> [WebhookSensor] in
            var dispatched = allServers[server.identifier] ?? [:]
            var outgoing = [WebhookSensor]()

            var replaced = [String]()

            for batch in batches {
                for sensor in batch.sensors {
                    guard let uniqueID = sensor.UniqueID else {
                        // Nothing to key freshness on, and the mapper drops it anyway.
                        outgoing.append(sensor)
                        continue
                    }

                    if let newer = dispatched[uniqueID], newer.readOrder > batch.readOrder {
                        replaced.append(uniqueID)
                        outgoing.append(newer.sensor)
                        continue
                    }

                    dispatched[uniqueID] = ReadSensor(sensor: sensor, readOrder: batch.readOrder)
                    outgoing.append(sensor)
                }
            }

            if !replaced.isEmpty {
                // One line for the whole run: an overlap can cover every sensor, on every server.
                Current.Log.verbose(
                    "keeping the values already sent to \(server.info.name) for \(replaced), " +
                        "which this run read before them"
                )
            }

            allServers[server.identifier] = dispatched
            return outgoing
        }
    }

    private func notifySignal(reason: SensorContainerUpdateReason) {
        let update = lastUpdate.read { $0 }
        for observer in currentObservers() {
            observer.sensorContainer(self, didSignalForUpdateBecause: reason, lastUpdate: update)
        }
    }

    private func updateSignaled(from type: SensorProvider.Type) {
        Current.Log.info("live update triggering from \(type)")
        notifySignal(reason: .signal)
    }
}
