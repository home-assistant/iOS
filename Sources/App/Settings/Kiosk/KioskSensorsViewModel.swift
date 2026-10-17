import Combine
import Foundation
import PromiseKit
import Shared
import UIKit

/// Backs the "Sensors" menu inside kiosk settings. The sensors shown here are the same
/// `WebhookSensor`s exposed in the standard sensor settings, and enabling/disabling them goes
/// through `Current.sensors`, so the two screens always mirror each other.
final class KioskSensorsViewModel: ObservableObject {
    /// Identifiers of the sensors surfaced in the kiosk sensors menu, in display order.
    static let sensorIds: [WebhookSensorId] = [.kioskMode, .kioskBrightness, .kioskVolume, .kioskScreensaver]
    private static let order: [String: Int] = Dictionary(
        uniqueKeysWithValues: sensorIds.enumerated().map { ($0.element.rawValue, $0.offset) }
    )

    @Published private(set) var sensors: [WebhookSensor] = []

    init() {
        Current.sensors.register(observer: self)
    }

    deinit {
        Current.sensors.unregister(observer: self)
    }

    func isEnabled(_ sensor: WebhookSensor) -> Bool {
        Current.sensors.isEnabledForAnyServer(sensor: sensor)
    }

    /// Kiosk mode belongs to the device rather than to one server, so its sensors are switched on
    /// everywhere at once here — the per-server choice lives in Settings → Sensors.
    func setEnabled(_ enabled: Bool, for sensor: WebhookSensor) {
        guard let uniqueID = sensor.UniqueID else { return }
        Current.sensors.setEnabledForAllServers(enabled, forUniqueID: uniqueID)
        // Reflect the change immediately; the sensor refresh triggered by the settings change
        // will follow up with fresh state values.
        objectWillChange.send()
    }

    func refresh() {
        firstly {
            HomeAssistantAPI.manuallyUpdate(
                applicationState: UIApplication.shared.applicationState,
                type: .userRequested
            )
        }.catch { error in
            Current.Log.error("Failed to refresh kiosk sensors: \(error.localizedDescription)")
        }
    }
}

// MARK: - SensorObserver

extension KioskSensorsViewModel: SensorObserver {
    func sensorContainer(
        _ container: SensorContainer,
        didSignalForUpdateBecause reason: SensorContainerUpdateReason,
        lastUpdate: SensorObserverUpdate?
    ) {
        refresh()
    }

    func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        firstly {
            update.sensors
        }.done { [weak self] sensors in
            let kioskSensors = sensors
                .filter { Self.order[$0.UniqueID ?? ""] != nil }
                .sorted { (Self.order[$0.UniqueID ?? ""] ?? 0) < (Self.order[$1.UniqueID ?? ""] ?? 0) }
            DispatchQueue.main.async {
                self?.sensors = kioskSensors
            }
        }
    }
}
