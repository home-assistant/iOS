import CoreMotion
import Foundation

/// Owns the single `CMAltimeter` session behind `Current.barometer` and fans its readings out to
/// every subscriber.
///
/// `CMAltimeter.startRelativeAltitudeUpdates(to:withHandler:)` keeps only one handler per altimeter,
/// so a second `start` on the same altimeter silently orphans the first caller's handler — the
/// failure behind issue #5100. Anything that wants pressure readings subscribes here rather than
/// starting a session of its own, so the pressure sensor and flight detection can read the barometer
/// at the same time.
public final class BarometerObserver {
    private let lock = NSLock()
    private var subscribers: [String: CMAltitudeHandler] = [:]
    private var isRunning = false
    private var cachedPressureKpa: Double?

    public init() {}

    /// The most recent pressure in kilopascals seen by the shared session, or nil when no session is
    /// running or it hasn't reported yet.
    public var latestPressureKpa: Double? {
        lock.lock()
        defer { lock.unlock() }
        return cachedPressureKpa
    }

    public var isUsable: Bool {
        Current.barometer.isAvailable() && Current.barometer.isAuthorized()
    }

    /// Delivers every reading of the shared session to `handler` until `removeSubscriber(id:)`,
    /// starting the session if it isn't running yet. Adding a subscriber under an id that is already
    /// registered replaces its handler.
    ///
    /// Returns false — registering nothing — when the hardware is missing or motion access hasn't
    /// been granted. Authorization is deliberately only checked, never requested: subscribing must
    /// not be able to raise a Motion & Fitness prompt on behalf of a caller that has no business
    /// asking for one.
    @discardableResult
    public func addSubscriber(id: String, handler: @escaping CMAltitudeHandler) -> Bool {
        guard isUsable else { return false }

        lock.lock()
        subscribers[id] = handler
        let shouldStart = !isRunning
        if shouldStart {
            isRunning = true
        }
        lock.unlock()

        if shouldStart {
            let queue = OperationQueue()
            queue.name = "barometer-observer"
            queue.maxConcurrentOperationCount = 1
            Current.barometer.startUpdatesOnQueueHandler(queue) { [weak self] data, error in
                self?.deliver(data: data, error: error)
            }
        }
        return true
    }

    public func removeSubscriber(id: String) {
        lock.lock()
        subscribers[id] = nil
        let shouldStop = subscribers.isEmpty && isRunning
        if shouldStop {
            isRunning = false
            cachedPressureKpa = nil
        }
        lock.unlock()

        if shouldStop {
            Current.barometer.stopUpdates()
        }
    }

    public func hasSubscriber(id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return subscribers[id] != nil
    }

    private func deliver(data: CMAltitudeData?, error: Error?) {
        lock.lock()
        if let data {
            cachedPressureKpa = data.pressure.doubleValue
        }
        let handlers = Array(subscribers.values)
        lock.unlock()

        for handler in handlers {
            handler(data, error)
        }
    }
}
