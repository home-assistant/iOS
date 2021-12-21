import CoreLocation
import Foundation
import HAKit
import PromiseKit
import Version

public struct SensorObserverUpdate {
    public let sensors: Guarantee<[WebhookSensor]>
    public let on: Date

    internal init(sensors: Guarantee<[WebhookSensor]>) {
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
        didSignalForUpdateBecause reason: SensorContainerUpdateReason
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
    private var providers = [SensorProvider.Type]()
    private var observers = NSHashTable<AnyObject>(options: .weakMemory)
    private var providerDependencies: SensorProviderDependencies

    init() {
        self.providerDependencies = SensorProviderDependencies()
        providerDependencies.updateSignalHandler = { [weak self] type in
            self?.updateSignaled(from: type)
        }
    }

    public func register(provider: SensorProvider.Type) {
        providers.append(provider)
    }

    public func register(observer: SensorObserver) {
        observers.add(observer)

        if let lastUpdate = lastUpdate {
            observer.sensorContainer(self, didUpdate: lastUpdate)
        }
    }

    public func unregister(observer: SensorObserver) {
        observers.remove(observer)
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
        return !disabledSensorIDs.contains(id)
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

        if value {
            disabledSensorIDs.remove(id)
        } else {
            disabledSensorIDs.insert(id)
        }
    }

    private var lastUpdate: SensorObserverUpdate? {
        didSet {
            guard let lastUpdate = lastUpdate else { return }
            observers
                .allObjects
                .compactMap { $0 as? SensorObserver }
                .forEach { $0.sensorContainer(self, didUpdate: lastUpdate) }
        }
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

    internal func sensors(
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
            let promises = providers
                .filter { providerType in
                    if let limitedTo = limitedTo {
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

        lastUpdate = .init(sensors: generatedSensors.map { [lastSentSensors] new in
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
                guard let self = self else { return true }
                switch (self.isEnabled(sensor: lhs), self.isEnabled(sensor: rhs)) {
                case (true, true): return lhs < rhs
                case (false, false): return lhs < rhs
                case (true, false): return true
                case (false, true): return false
                }
            })
        })

        return generatedSensors.mapValues { [weak self] sensor -> WebhookSensor in
            guard let self = self else { return sensor }

            if self.isAllowedToSend(sensor: sensor, for: server) {
                return sensor
            } else {
                return WebhookSensor(redacting: sensor)
            }
        }.map(SensorResponse.init(sensors:))
    }

    private func notifySignal(reason: SensorContainerUpdateReason) {
        observers
            .allObjects
            .compactMap { $0 as? SensorObserver }
            .forEach { $0.sensorContainer(self, didSignalForUpdateBecause: reason) }
    }

    private func updateSignaled(from type: SensorProvider.Type) {
        Current.Log.info("live update triggering from \(type)")
        notifySignal(reason: .signal)
    }
}
