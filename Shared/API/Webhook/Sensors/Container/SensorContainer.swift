import Foundation
import PromiseKit
import CoreLocation

public struct SensorObserverUpdate {
    public let sensors: Guarantee<[WebhookSensor]>
    public let on: Date

    internal init(sensors: Guarantee<[WebhookSensor]>) {
        self.sensors = sensors
        self.on = Current.date()
    }
}

public protocol SensorObserver: AnyObject {
    func sensorContainer(
        _ container: SensorContainer,
        didUpdate update: SensorObserverUpdate
    )
    func sensorContainerDidSignalForUpdate(
        _ container: SensorContainer
    )
}

public class SensorContainer {
    private var providers = [SensorProvider.Type]()
    private var observers = NSHashTable<AnyObject>(options: .weakMemory)
    private var providerDependencies: SensorProviderDependencies

    init() {
        self.providerDependencies = SensorProviderDependencies()
        self.providerDependencies.updateSignalHandler = { [weak self] type in
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

    private var lastUpdate: SensorObserverUpdate? {
        didSet {
            guard let lastUpdate = lastUpdate else { return }

            DispatchQueue.main.async { [observers] in
                observers
                    .allObjects
                    .compactMap { $0 as? SensorObserver }
                    .forEach { $0.sensorContainer(self, didUpdate: lastUpdate) }
            }
        }
    }

    private func updateLastUpdate() {
        lastUpdate = .init(sensors: Self.allPersisted())
    }

    private static func allPersisted() -> Guarantee<[WebhookSensor]> {
        .value(
            Current.realm().objects(PersistedSensor.self).map(\.sensor).sorted(by: {
                $0.Name ?? "" < $1.Name ?? ""
            })
        )
    }

    private static func isPersisted(sensor: WebhookSensor) -> Bool {
        if let uniqueID = sensor.UniqueID,
           let persisted = Current.realm().object(ofType: PersistedSensor.self, forPrimaryKey: uniqueID) {
            return persisted.sensor == sensor
        } else {
            return false
        }
    }

    private static func persist(sensor: WebhookSensor) {
        let realm = Current.realm()
        precondition(realm.isInWriteTransaction)

        guard let uniqueID = sensor.UniqueID else {
            assertionFailure("uniqueID should not be nil")
            Current.Log.error("failed to persist sensor: unique ID was nil")
            return
        }

        if let existing = realm.object(ofType: PersistedSensor.self, forPrimaryKey: uniqueID) {
            existing.sensor = sensor
        } else if let persisted = PersistedSensor(sensor: sensor) {
            realm.add(persisted, update: .all)
        } else {
            Current.Log.error("failed to persist sensor: couldn't find or create")
        }
    }

    internal func sensors(
        reason: SensorProviderRequest.Reason,
        location: CLLocation? = nil
    ) -> Guarantee<[WebhookSensor]> {
        let request = SensorProviderRequest(
            reason: reason,
            dependencies: providerDependencies,
            location: location
        )

        return firstly {
            let promises = providers
                .map { providerType in providerType.init(request: request) }
                .map { provider in provider.sensors().map { ($0, provider) } }

            return when(resolved: promises)
        }.map { (sensors: [Result<([WebhookSensor], SensorProvider)>]) -> [WebhookSensor] in
            // now that we are done, we don't need to keep a strong reference to the provider instance anymore
            sensors.compactMap { (result: Result<([WebhookSensor], SensorProvider)>) -> [WebhookSensor]? in
                if case .fulfilled(let value) = result {
                    return value.0
                } else {
                    return nil
                }
            }.flatMap { $0 }
        }.filterValues { sensor in
            if request.reason.shouldAllowPersistedFilter {
                return !Self.isPersisted(sensor: sensor)
            } else {
                return true
            }
        }.get(on: .global(qos: .userInitiated)) { [weak self] sensors in
            do {
                try Current.realm().write {
                    for sensor in sensors {
                        Self.persist(sensor: sensor)
                    }
                }
                self?.updateLastUpdate()
            } catch {
                Current.Log.error("couldn't update persisted sensors: \(error)")
            }
        }
    }

    private func updateSignaled(from type: SensorProvider.Type) {
        Current.Log.info("live update triggering from \(type)")

        observers
            .allObjects
            .compactMap { $0 as? SensorObserver }
            .forEach { $0.sensorContainerDidSignalForUpdate(self) }
    }
}
