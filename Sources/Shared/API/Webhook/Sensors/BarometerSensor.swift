import CoreMotion
import Foundation
import PromiseKit

final class BarometerSensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler {
    private let signal: () -> Void
    private let subscriberID = "barometer-signaler-\(UUID().uuidString)"
    private var lastSignaledPressureKpa: Double?

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
        guard Current.barometerObserver.addSubscriber(id: subscriberID, handler: { [weak self] data, _ in
            guard let self, let data else { return }
            let newPressure = data.pressure.doubleValue
            latestPressureKpa = newPressure
            if let last = lastSignaledPressureKpa, abs(newPressure - last) < 0.01 {
                // Less than 0.1 hPa change, skip update
                return
            }
            lastSignaledPressureKpa = newPressure
            signal()
        }) else { return }
        isObserving = true

        #if DEBUG
        notifyObservation?()
        #endif
    }

    override func stopObserving() {
        super.stopObserving()
        guard isObserving else { return }
        Current.barometerObserver.removeSubscriber(id: subscriberID)
        lastSignaledPressureKpa = nil
        latestPressureKpa = nil
        isObserving = false
    }

    private let oneShotLock = NSLock()
    private var pendingOneShot: Promise<CMAltitudeData>?

    /// Performs a single relative-altitude read, coalescing concurrent callers onto one reading.
    ///
    /// Sensor generation waits for *every* provider (`when(resolved:)`), so a read that never
    /// settles leaves the whole payload promise unresolved and no `update_sensor_states` webhook is
    /// ever sent for that server (issue #5100). Sharing one in-flight read keeps concurrent
    /// per-server sweeps down to a single reading, and a timeout guarantees the promise always
    /// settles even if the hardware never reports.
    func oneShotReading() -> Promise<CMAltitudeData> {
        let lock = oneShotLock
        lock.lock()
        if let pendingOneShot {
            lock.unlock()
            return pendingOneShot
        }

        let (promise, seal) = Promise<CMAltitudeData>.pending()
        pendingOneShot = promise
        lock.unlock()

        let oneShotID = "barometer-sensor-one-shot-\(UUID().uuidString)"
        var timeoutWork: DispatchWorkItem?
        var resolved = false
        // Called from the altimeter handler and from the timeout; the lock serializes them so the
        // promise resolves exactly once and the shared slot is cleared for the next read.
        let finish: (CMAltitudeData?, Error?) -> Void = { [weak self] data, error in
            lock.lock()
            let alreadyResolved = resolved
            resolved = true
            if self?.pendingOneShot === promise {
                self?.pendingOneShot = nil
            }
            lock.unlock()

            guard !alreadyResolved else { return }
            timeoutWork?.cancel()
            Current.barometerObserver.removeSubscriber(id: oneShotID)

            if let data {
                seal.fulfill(data)
            } else {
                seal.reject(error ?? BarometerSensor.BarometerError.noData)
            }
        }

        let work = DispatchWorkItem { finish(nil, BarometerSensor.BarometerError.noData) }
        timeoutWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5, execute: work)

        guard Current.barometerObserver.addSubscriber(id: oneShotID, handler: { data, error in
            finish(data, error)
        }) else {
            finish(nil, BarometerSensor.BarometerError.unavailable)
            return promise
        }

        return promise
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

        // If the signaler is actively observing, its cached pressure is already current, so there is
        // nothing for a one-shot read to add.
        if let cachedKpa = signaler.latestPressureKpa {
            return .value([Self.pressureSensor(fromKpa: cachedKpa)])
        } else if signaler.isObserving {
            // Signaler started but no data yet — its first reading is moments away
            return .init(error: BarometerError.noData)
        }

        guard Current.barometer.isAuthorized() else {
            return .init(error: BarometerError.unauthorized)
        }

        guard Current.barometer.isAvailable() else {
            Current.Log.warning("Barometer is not available")
            return .init(error: BarometerError.unavailable)
        }

        // Route through the signaler so concurrent per-server sweeps share a single reading rather
        // than each waiting out its own (see `oneShotReading`, issue #5100).
        return signaler.oneShotReading().map { data in
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
}
