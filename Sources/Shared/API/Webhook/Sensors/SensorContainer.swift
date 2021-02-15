import CoreLocation
import Foundation
import PromiseKit

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

public struct SensorResponse {
    /// The sensors that require update
    public let sensors: [WebhookSensor]
    /// Invoked when the sensor update's values have been successfully sent to the server
    public func didPersist() {
        didPersistHandler(sensors)
    }

    fileprivate init(sensors: [WebhookSensor], didPersistHandler: @escaping ([WebhookSensor]) -> Void) {
        self.sensors = sensors
        self.didPersistHandler = didPersistHandler
    }

    private let didPersistHandler: ([WebhookSensor]) -> Void
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

    private var lastUpdate: SensorObserverUpdate? {
        didSet {
            guard let lastUpdate = lastUpdate else { return }
            observers
                .allObjects
                .compactMap { $0 as? SensorObserver }
                .forEach { $0.sensorContainer(self, didUpdate: lastUpdate) }
        }
    }

    private class LastSentSensors {
        public private(set) var queue = DispatchQueue(label: "lastSentSensors-update")
        private var value = [String: WebhookSensor]()
        private var pendingUUID = UUID()

        private func nextPendingUUID() -> UUID {
            dispatchPrecondition(condition: .onQueue(queue))

            let uuid = UUID()
            pendingUUID = uuid
            return uuid
        }

        func filter(sensors: [WebhookSensor]) -> ([WebhookSensor], UUID) {
            dispatchPrecondition(condition: .onQueue(queue))

            let filteredSensors = sensors.filter { sensor in
                if let uniqueID = sensor.UniqueID {
                    return value[uniqueID] != sensor
                } else {
                    return false
                }
            }

            for key in filteredSensors.compactMap(\.UniqueID) {
                // now that we're about to send up a new value, until we hear back we can't trust our cache
                value[key] = nil
            }

            return (filteredSensors, nextPendingUUID())
        }

        func combined(with sensors: [WebhookSensor], ignoringKeys: Set<String> = .init()) -> [String: WebhookSensor] {
            dispatchPrecondition(condition: .onQueue(queue))
            return sensors.reduce(into: value) { result, sensor in
                if let uniqueID = sensor.UniqueID, !ignoringKeys.contains(uniqueID) {
                    result[uniqueID] = sensor
                }
            }
        }

        func combine(with sensors: [WebhookSensor], uuid: UUID) {
            let isOutOfOrder = uuid != pendingUUID

            if isOutOfOrder {
                let existingKeys = Set(value.keys)

                // we can't trust our local cache anymore since the out-of-order request may have overwritten
                // this is similar to how we don't keep a cache around in-between network request start and end
                sensors.compactMap { sensor in sensor.UniqueID.map { (uniqueID: $0, sensor: sensor) } }
                    .filter { value[$0.uniqueID] != $0.sensor }
                    .forEach {
                        value.removeValue(forKey: $0.uniqueID)
                    }

                // don't override anything that's already persisted, but allow things in if they're not already saved
                // we also avoid inserting into the cache anything that may have been overridden
                value = combined(with: sensors, ignoringKeys: existingKeys)
            } else {
                // latest update, we can trust all the values are the latest we've sent
                value = combined(with: sensors)
            }
        }
    }

    private var lastSentSensors: LastSentSensors = .init()

    internal func sensors(
        reason: SensorProviderRequest.Reason,
        location: CLLocation? = nil
    ) -> Guarantee<SensorResponse> {
        let request = SensorProviderRequest(
            reason: reason,
            dependencies: providerDependencies,
            location: location
        )

        let generatedSensors = firstly {
            let promises = providers
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

        switch request.reason {
        case .trigger:
            let filteredSensors = firstly {
                generatedSensors
            }.map(on: lastSentSensors.queue) { [self] sensors -> ([WebhookSensor], UUID) in
                lastSentSensors.filter(sensors: sensors)
            }

            // only store when we know we're sending the maximum kind of data
            lastUpdate = .init(sensors: filteredSensors.map(on: lastSentSensors.queue) { [self] new, _ in
                // doesn't store the sent values, that happens when the network request ends
                // this is just what's presented to the user, so we always have the latest version
                lastSentSensors.combined(with: new).values.sorted()
            })

            return filteredSensors.map { [self] sensors, uuid in
                SensorResponse(sensors: sensors, didPersistHandler: { sensors in
                    lastSentSensors.queue.async {
                        // finally store what we sent, so we can avoid sending again
                        lastSentSensors.combine(with: sensors, uuid: uuid)
                    }
                })
            }
        case .registration:
            return generatedSensors.map { SensorResponse(sensors: $0, didPersistHandler: { _ in }) }
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
