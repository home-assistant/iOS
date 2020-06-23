import Foundation
import PromiseKit

public protocol SensorObserver: AnyObject {
    func sensorContainer(
        _ container: SensorContainer,
        didUpdate sensors: Promise<[WebhookSensor]>,
        on date: Date
    )
}

public class SensorContainer {
    private var providers = [SensorProvider.Type]()
    private var observers = NSHashTable<AnyObject>(options: .weakMemory)

    public func register(provider: SensorProvider.Type) {
        providers.append(provider)
    }

    public func register(observer: SensorObserver) {
        observers.add(observer)

        if let lastUpdate = lastUpdate {
            update(observer: observer, lastUpdate: lastUpdate)
        }
    }

    public func unregister(observer: SensorObserver) {
        observers.remove(observer)
    }

    private struct LastUpdate {
        let date: Date
        let sensors: Promise<[WebhookSensor]>

        init(sensors: Promise<[WebhookSensor]>) {
            self.sensors = sensors
            self.date = Current.date()
        }
    }

    private var lastUpdate: LastUpdate? {
        didSet {
            guard let lastUpdate = lastUpdate else { return }
            observers
                .allObjects
                .compactMap { $0 as? SensorObserver }
                .forEach { update(observer: $0, lastUpdate: lastUpdate) }
        }
    }

    private func update(observer: SensorObserver, lastUpdate: LastUpdate) {
        observer.sensorContainer(self, didUpdate: lastUpdate.sensors, on: lastUpdate.date)
    }

    internal func sensors(request: SensorProviderRequest) -> Promise<[WebhookSensor]> {
        let sensors = firstly {
            when(resolved: providers.map { $0.sensors(request: request) })
        }.map { (sensors: [Result<[WebhookSensor]>]) throws -> [WebhookSensor] in
            sensors.compactMap { (result: Result<[WebhookSensor]>) -> [WebhookSensor]? in
                if case .fulfilled(let value) = result {
                    return value
                } else {
                    return nil
                }
            }.flatMap { $0 }
        }

        switch request.reason {
        case .trigger:
            // only store when we know we're sending the maximum kind of data
            lastUpdate = .init(sensors: sensors)
        case .registration:
            break
        }

        return sensors
    }
}
