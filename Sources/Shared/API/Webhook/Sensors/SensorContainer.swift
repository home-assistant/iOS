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
            observers
                .allObjects
                .compactMap { $0 as? SensorObserver }
                .forEach { $0.sensorContainer(self, didUpdate: lastUpdate) }
        }
    }

    // TODO: this is last 'returned' not last 'sent' - if we cancel a previous request, this will be wrong
    // this needs to update only when network requests complete successfully
    private var lastSentSensors: [String: WebhookSensor] = [:]

    internal func sensors(
        reason: SensorProviderRequest.Reason,
        location: CLLocation? = nil
    ) -> Guarantee<[WebhookSensor]> {
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
                if case .fulfilled(let value) = result {
                    return value.0
                } else {
                    return nil
                }
            }.flatMap { $0 }
        }

        let filteredSensors = generatedSensors.filterValues(on: .main) { [self] sensor in
            if let uniqueID = sensor.UniqueID {
                return lastSentSensors[uniqueID] != sensor
            } else {
                return false
            }
        }

        switch request.reason {
        case .trigger:
            // only store when we know we're sending the maximum kind of data
            // we start with the only-updated set, because we want to replace on them but keep the rest
            // so that we continue to use e.g. not-generated-this-round sensors from the array
            lastUpdate = .init(sensors: filteredSensors.map(on: .main) { [self] new -> [WebhookSensor] in
                lastSentSensors = new.reduce(into: lastSentSensors) { result, sensor in
                    if let uniqueID = sensor.UniqueID {
                        result[uniqueID] = sensor
                    }
                }
                return lastSentSensors.values.sorted()
            }
        )
        case .registration:
            break
        }

        if request.reason.shouldSkipChangeFilter {
            return generatedSensors
        } else {
            return filteredSensors
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
