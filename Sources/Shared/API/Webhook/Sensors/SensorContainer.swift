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
    case settingsChange
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

    private var disabledSensorIDs: Set<String> {
        get {
            Set(Current.settingsStore.prefs.object(forKey: "disabledSensors") as? [String] ?? [])
        }
        set {
            Current.settingsStore.prefs.set(Array(newValue), forKey: "disabledSensors")
            notifySignal(reason: .settingsChange)
        }
    }

    public func isEnabled(sensor: WebhookSensor) -> Bool {
        guard let id = sensor.UniqueID else { return false }
        return isEnabled(uniqueID: id)
    }

    public func isEnabled(uniqueID: String) -> Bool {
        !disabledSensorIDs.contains(uniqueID)
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
        if value {
            disabledSensorIDs.remove(id)
        } else {
            disabledSensorIDs.insert(id)
        }
    }

    private let lastUpdate = HAProtected<SensorObserverUpdate?>(value: nil)

    private func currentObservers() -> [SensorObserver] {
        observers.read { $0.allObjects.compactMap { $0 as? SensorObserver } }
    }

    private func setLastUpdate(_ update: SensorObserverUpdate) {
        lastUpdate.mutate { $0 = update }
        currentObservers().forEach { $0.sensorContainer(self, didUpdate: update) }
    }

    private struct LastSentSensors {
        private var value = [String: WebhookSensor]()

        var sensors: AnyCollection<WebhookSensor> {
            AnyCollection(value.values)
        }

        private func combined(
            with sensors: [WebhookSensor],
            ignoringKeys: Set<String>
        ) -> [String: WebhookSensor] {
            sensors.reduce(into: value) { result, sensor in
                if let uniqueID = sensor.UniqueID, !ignoringKeys.contains(uniqueID) {
                    result[uniqueID] = sensor
                }
            }
        }

        mutating func combine(with sensors: [WebhookSensor], ignoringExisting: Bool) {
            let keys = ignoringExisting ? Set(value.keys) : Set()
            value = combined(with: sensors, ignoringKeys: keys)
        }
    }

    private var lastSentSensors: HAProtected<LastSentSensors> = .init(value: .init())

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

        let generatedSensors = firstly {
            let promises = providers.read { $0 }
                .filter { providerType in
                    if let limitedTo {
                        return limitedTo.contains(where: { ObjectIdentifier($0) == ObjectIdentifier(providerType) })
                    } else {
                        return true
                    }
                }
                .map { providerType in providerType.init(request: request) }
                .map { provider in provider.sensors().map { ($0, provider) } }

            return when(resolved: promises)
        }.map { (sensors: [Result<([WebhookSensor], SensorProvider)>]) -> [WebhookSensor] in
            // now that we are done, we don't need to keep a strong reference to the provider instance anymore
            sensors.compactMap { (result: Result<([WebhookSensor], SensorProvider)>) -> [WebhookSensor]? in
                if case let .fulfilled(value) = result {
                    return value.0
                } else {
                    return nil
                }
            }.flatMap { $0 }
        }

        setLastUpdate(.init(sensors: generatedSensors.map { [lastSentSensors] new in
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

            return lastSentSensors.mutate { lastSentSensors -> AnyCollection<WebhookSensor> in
                lastSentSensors.combine(with: new, ignoringExisting: ignoringExisting)
                return lastSentSensors.sensors
            }.sorted(by: { [weak self] lhs, rhs in
                guard let self else { return true }
                switch (isEnabled(sensor: lhs), isEnabled(sensor: rhs)) {
                case (true, true): return lhs < rhs
                case (false, false): return lhs < rhs
                case (true, false): return true
                case (false, true): return false
                }
            })
        }))

        return generatedSensors.mapValues { [weak self] sensor -> WebhookSensor in
            guard let self else { return sensor }

            if isAllowedToSend(sensor: sensor, for: server) {
                return sensor
            } else {
                return WebhookSensor(redacting: sensor)
            }
        }.map(SensorResponse.init(sensors:))
    }

    private func notifySignal(reason: SensorContainerUpdateReason) {
        let update = lastUpdate.read { $0 }
        currentObservers().forEach {
            $0.sensorContainer(self, didSignalForUpdateBecause: reason, lastUpdate: update)
        }
    }

    private func updateSignaled(from type: SensorProvider.Type) {
        Current.Log.info("live update triggering from \(type)")
        notifySignal(reason: .signal)
    }
}
