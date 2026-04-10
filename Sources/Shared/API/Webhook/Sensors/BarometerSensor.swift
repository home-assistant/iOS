import CoreMotion
import Foundation
import PromiseKit

final class BarometerSensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler {
    private let signal: () -> Void
    private var lastPressureKpa: Double?
    private var observationQueue: OperationQueue?

    /// The most recent altitude data received from CMAltimeter, used by BarometerSensor
    /// to avoid starting a separate one-shot read that would conflict with the signaler's stream.
    private(set) var latestData: CMAltitudeData?

    required init(signal: @escaping () -> Void) {
        self.signal = signal
        super.init(relatedSensorsIds: [.pressure])
    }

    override func observe() {
        super.observe()
        guard !isObserving else { return }
        guard Current.barometer.isAvailable(), Current.barometer.isAuthorized() else { return }

        let queue = OperationQueue()
        queue.name = "barometer-signaler"
        observationQueue = queue

        Current.barometer.startUpdatesOnQueueHandler(queue) { [weak self] data, _ in
            guard let self, let data else { return }
            latestData = data
            let newPressure = data.pressure.doubleValue
            if let last = lastPressureKpa, abs(newPressure - last) < 0.01 {
                // Less than 0.1 hPa change, skip update
                return
            }
            lastPressureKpa = newPressure
            signal()
        }
        isObserving = true

        #if DEBUG
        notifyObservation?()
        #endif
    }

    override func stopObserving() {
        super.stopObserving()
        guard isObserving else { return }
        Current.barometer.stopUpdates()
        observationQueue = nil
        lastPressureKpa = nil
        latestData = nil
        isObserving = false
    }
}

public class BarometerSensor: SensorProvider {
    public enum BarometerError: Error, Equatable {
        case unauthorized
        case unavailable
        case noData
    }

    public let request: SensorProviderRequest
    public required init(request: SensorProviderRequest) {
        self.request = request
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        let signaler: BarometerSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        return firstly {
            // If the signaler is actively observing, use its cached data to avoid
            // starting a separate one-shot read that would stop the signaler's stream.
            // If observing but no data yet, fall back to noData rather than racing.
            if let cached = signaler.latestData {
                return Promise.value(cached)
            } else if signaler.isObserving {
                return .init(error: BarometerError.noData)
            }
            return latestBarometerData()
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
