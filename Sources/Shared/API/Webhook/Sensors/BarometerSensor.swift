import CoreMotion
import Foundation
import PromiseKit

public class BarometerSensor: SensorProvider {
    public enum BarometerError: Error {
        case unauthorized
        case unavailable
        case noData
    }

    public let request: SensorProviderRequest
    public required init(request: SensorProviderRequest) {
        self.request = request
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        firstly {
            latestBarometerData()
        }.map { data in
            // CMAltitudeData.pressure is in kilopascals; HA pressure device class expects hPa (= mbar)
            let pressureHpa = data.pressure.doubleValue * 10.0

            let pressureSensor = WebhookSensor(
                name: "Pressure",
                uniqueID: WebhookSensorId.pressure.rawValue,
                icon: "mdi:gauge",
                deviceClass: .pressure,
                state: round(pressureHpa * 100) / 100,
                unit: "hPa"
            )

            return [pressureSensor]
        }
    }

    private func latestBarometerData() -> Promise<CMAltitudeData> {
        guard Current.barometer.isAuthorized() else {
            return .init(error: BarometerError.unauthorized)
        }

        guard Current.barometer.isAvailable() else {
            Current.Log.warning("Barometer is not available")
            return .init(error: BarometerError.unavailable)
        }

        let (promise, seal) = Promise<CMAltitudeData>.pending()
        let queue = OperationQueue()
        queue.name = "barometer-sensor"

        Current.barometer.startUpdatesOnQueueHandler(queue) { data, error in
            // We only need a single reading, so stop updates immediately
            Current.barometer.stopUpdates()

            if let data {
                seal.fulfill(data)
            } else if let error {
                seal.reject(error)
            } else {
                seal.reject(BarometerError.noData)
            }
        }

        return promise
    }
}
