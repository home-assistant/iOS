import CoreLocation
import Foundation
import Shared
import UIKit

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
        switch Current.location.permissionStatus {
        case .denied, .restricted:
            // Open iOS settings
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        case .authorizedWhenInUse, .authorizedAlways:
            shouldComplete = true
        default:
            break
        }
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
        _ container: SensorContainer,
        didSignalForUpdateBecause reason: SensorContainerUpdateReason,
        lastUpdate: SensorObserverUpdate?
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

        // Enable sensors if we have permission and user has chosen to allow location
        if [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus) {
            enableLocationSensor()
        }

        // Only complete if the user has made a choice
        guard manager.authorizationStatus != .notDetermined else { return }
        DispatchQueue.main.async { [weak self] in
            self?.shouldComplete = true
        }
    }
}
