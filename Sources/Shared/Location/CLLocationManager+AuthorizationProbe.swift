import CoreLocation
import Foundation
import HAKit

public extension CLLocationManager {
    /// The one manager used to read authorization state from any thread.
    ///
    /// `authorizationStatus` performs synchronous XPC to locationd, so the sensors and the webhook
    /// read it off the main thread. Creating a `CLLocationManager` there is what crashed on Mac
    /// Catalyst, though: its initializer reads `UIApplication.applicationState`, which walks the
    /// window scenes and is only safe on the main thread. So the manager is built on main, once,
    /// and the status reads keep happening wherever the caller is.
    static var authorizationProbe: CLLocationManager {
        authorizationProbe(in: authorizationProbeStorage, make: CLLocationManager.init)
    }

    /// `authorizationProbe` with its storage and the manager's construction explicit, so a test
    /// can watch a background first access build on the main thread.
    internal static func authorizationProbe(
        in storage: HAProtected<CLLocationManager?>,
        make: () -> CLLocationManager
    ) -> CLLocationManager {
        if let existing = storage.read({ $0 }) {
            return existing
        }
        // Built outside the lock so a thread hopping to main never holds it: the first instance
        // stored wins and a loser is simply dropped.
        let made = Thread.isMainThread ? make() : DispatchQueue.main.sync(execute: make)
        return storage.mutate { storage in
            if let existing = storage {
                return existing
            }
            storage = made
            return made
        }
    }

    private static let authorizationProbeStorage = HAProtected<CLLocationManager?>(value: nil)
}
