import CoreMotion
import Foundation
import PromiseKit

final class BarometerSensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler {
    private let signal: () -> Void
    private var lastSignaledPressureKpa: Double?
    private var observationQueue: OperationQueue?

    /// The most recent pressure in kilopascals from CMAltimeter, used by BarometerSensor
    /// to avoid starting a separate one-shot read that would conflict with the signaler's stream.
    private(set) var latestPressureKpa: Double?

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
        queue.maxConcurrentOperationCount = 1
        observationQueue = queue

        Current.barometer.startUpdatesOnQueueHandler(queue) { [weak self] data, _ in
            guard let self, let data else { return }
            let newPressure = data.pressure.doubleValue
            latestPressureKpa = newPressure
            if let last = lastSignaledPressureKpa, abs(newPressure - last) < 0.01 {
                // Less than 0.1 hPa change, skip update
                return
            }
            lastSignaledPressureKpa = newPressure
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
        lastSignaledPressureKpa = nil
        latestPressureKpa = nil
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

        // If the signaler is actively observing, use its cached pressure to avoid
        // starting a separate one-shot read that would stop the signaler's stream.
        if let cachedKpa = signaler.latestPressureKpa {
            return .value([Self.pressureSensor(fromKpa: cachedKpa)])
        } else if signaler.isObserving {
            // Signaler started but no data yet — skip rather than racing with a one-shot
            return .init(error: BarometerError.noData)
        }

        return firstly {
            latestBarometerData()
        }.map { data in
            [Self.pressureSensor(fromKpa: data.pressure.doubleValue)]
        }
    }

    static func pressureSensor(fromKpa kpa: Double) -> WebhookSensor {
        // CMAltitudeData.pressure is in kilopascals; HA pressure device class expects hPa (= mbar)
        let pressureHpa = kpa * 10.0
        return WebhookSensor(
            name: "Pressure",
            uniqueID: WebhookSensorId.pressure.rawValue,
            icon: "mdi:gauge",
            deviceClass: .pressure,
            state: round(pressureHpa * 100) / 100,
            unit: "hPa"
        )
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
        queue.maxConcurrentOperationCount = 1

        // startRelativeAltitudeUpdates is a streaming API, so an in-flight callback
        // could arrive after stopUpdates(). Guard against double-resolving the promise,
        // and ensure late callbacks become no-ops before stopping updates.
        var resolved = false
        Current.barometer.startUpdatesOnQueueHandler(queue) { data, error in
            guard !resolved else { return }
            resolved = true
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
