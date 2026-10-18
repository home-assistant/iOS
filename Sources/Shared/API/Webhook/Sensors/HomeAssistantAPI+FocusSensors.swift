import Foundation
import PromiseKit

public extension HomeAssistantAPI {
    /// Sends only the Focus sensors, for the callers that are reacting to a Focus change.
    ///
    /// A full update asks every provider — CoreMotion, HealthKit, the geocoder — and the Focus
    /// Filter runs in an app iOS has just launched in the background, where all of that competes
    /// with the launch itself and can outlast the little time the process gets. The two sensors
    /// that changed are the only ones the caller is waiting on.
    func updateFocusSensors(trigger: LocationUpdateTrigger = .Signaled) -> Promise<Void> {
        var providers: [SensorProvider.Type] = [FocusSensor.self]
        #if os(iOS) && !targetEnvironment(macCatalyst)
        // Focus Filters, and so the name of the running Focus, are an iOS feature.
        providers.append(FocusNameSensor.self)
        #endif
        return UpdateSensors(trigger: trigger, limitedTo: providers)
    }
}
