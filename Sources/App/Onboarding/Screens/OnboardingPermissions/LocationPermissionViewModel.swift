import CoreLocation
import Foundation
import Shared

final class LocationPermissionViewModel: NSObject, ObservableObject {
    @Published var showDenyAlert: Bool = false
    @Published var shouldComplete: Bool = false
    private let locationManager = CLLocationManager()
    private var webhookSensors: [WebhookSensor] = []

    private let sensorIdsToEnableDisable: [WebhookSensorId] = [
        .geocodedLocation,
        .connectivityBSID,
        .connectivitySSID,
    ]

    override init() {
        super.init()
        Current.sensors.register(observer: self)
    }

    func requestLocationPermission() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }

    func disableLocationSensor() {
        for sensor in locationRelatedSensors() {
            Current.sensors.setEnabled(false, for: sensor)
        }
    }

    func enableLocationSensor() {
        for sensor in locationRelatedSensors() {
            Current.sensors.setEnabled(true, for: sensor)
        }
    }

    private func locationRelatedSensors() -> [WebhookSensor] {
        webhookSensors.filter { sensor in
            sensorIdsToEnableDisable.map(\.rawValue).contains(sensor.UniqueID)
        }
    }
}

extension LocationPermissionViewModel: SensorObserver {
    func sensorContainer(
        _ container: Shared.SensorContainer,
        didSignalForUpdateBecause reason: Shared.SensorContainerUpdateReason
    ) {
        /* no-op */
    }

    func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        update.sensors.done { [weak self] sensors in
            self?.webhookSensors = sensors
        }
    }
}

extension LocationPermissionViewModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            break
        case .restricted:
            break
        case .denied:
            disableLocationSensor()
        case .authorizedAlways:
            break
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        case .authorized:
            break
        @unknown default:
            break
        }

        guard manager.authorizationStatus != .notDetermined else { return }
        DispatchQueue.main.async { [weak self] in
            self?.shouldComplete = true
        }
    }
}
