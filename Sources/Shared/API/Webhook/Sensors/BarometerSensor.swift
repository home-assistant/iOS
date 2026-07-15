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

    private let oneShotLock = NSLock()
    private var pendingOneShot: Promise<CMAltitudeData>?

    /// Performs a single relative-altitude read, coalescing concurrent callers onto one
    /// `CMAltimeter` session.
    ///
    /// `CMAltimeter.startRelativeAltitudeUpdates(to:withHandler:)` keeps only a single handler on
    /// the shared altimeter (`Current.barometer`), so a second concurrent `start` orphans the first
    /// caller's handler — which then never fires. Because sensor generation waits for *every*
    /// provider (`when(resolved:)`), that orphaned read leaves the whole payload promise unresolved
    /// and no `update_sensor_states` webhook is ever sent for that server. In a multi-server setup
    /// the servers' sweeps are dispatched in list order, so the first (default) server was
    /// deterministically starved while the last one worked. See issue #5100.
    ///
    /// Sharing one in-flight read fixes that, and a timeout guarantees the promise always settles
    /// even if the hardware never reports (which would otherwise hang the sweep forever).
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

        let queue = OperationQueue()
        queue.name = "barometer-sensor"
        queue.maxConcurrentOperationCount = 1

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
            Current.barometer.stopUpdates()

            if let data {
                seal.fulfill(data)
            } else {
                seal.reject(error ?? BarometerSensor.BarometerError.noData)
            }
        }

        let work = DispatchWorkItem { finish(nil, BarometerSensor.BarometerError.noData) }
        timeoutWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5, execute: work)

        Current.barometer.startUpdatesOnQueueHandler(queue) { data, error in
            finish(data, error)
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

        // If the signaler is actively observing, use its cached pressure to avoid
        // starting a separate one-shot read that would stop the signaler's stream.
        if let cachedKpa = signaler.latestPressureKpa {
            return .value([Self.pressureSensor(fromKpa: cachedKpa)])
        } else if signaler.isObserving {
            // Signaler started but no data yet — skip rather than racing with a one-shot
            return .init(error: BarometerError.noData)
        }

        guard Current.barometer.isAuthorized() else {
            return .init(error: BarometerError.unauthorized)
        }

        guard Current.barometer.isAvailable() else {
            Current.Log.warning("Barometer is not available")
            return .init(error: BarometerError.unavailable)
        }

        // Route through the signaler so concurrent per-server sweeps share a single altimeter
        // read instead of orphaning each other's handler (see `oneShotReading`, issue #5100).
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
