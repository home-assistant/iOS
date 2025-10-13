import CoreLocation
import Foundation
import Shared
import UIKit

final class OnboardingPermissionsNavigationViewModel: NSObject, ObservableObject {
    enum LocationPermissionContext {
        case notRequested
        case shareWithHomeAssistant
        case secureLocalConnection
    }

    @Published var locationPermissionGranted: Bool = false

    @Published var locationPermissionContext: LocationPermissionContext = .notRequested

    private let locationManager = CLLocationManager()
    private var webhookSensors: [WebhookSensor] = []
    private let onboardingServer: Server

    private let sensorIdsToEnableDisable: [WebhookSensorId] = [
        .geocodedLocation,
        .connectivityBSID,
        .connectivitySSID,
    ]

    init(onboardingServer: Server) {
        self.onboardingServer = onboardingServer
        super.init()
        Current.sensors.register(observer: self)
    }

    func requestLocationPermissionToShareWithHomeAssistant() {
        locationPermissionContext = .shareWithHomeAssistant
        requestLocationPermission()
    }

    func requestLocationPermissionForSecureLocalConnection() {
        locationPermissionContext = .secureLocalConnection
        requestLocationPermission()
    }

    func setLessSecureLocalConnection() {
        onboardingServer.update { info in
            info.connection.localAccessSecurityLevel = .lessSecure
        }
    }

    func disableLocationSensor() {
        for sensor in locationRelatedSensors() {
            Current.sensors.setEnabled(false, for: sensor)
        }
    }

    private func enableLocationSensor() {
        for sensor in locationRelatedSensors() {
            Current.sensors.setEnabled(true, for: sensor)
        }
    }

    private func requestLocationPermission() {
        switch Current.location.permissionStatus {
        case .denied, .restricted:
            // Open iOS settings
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        case .authorizedWhenInUse, .authorizedAlways:
            locationPermissionGranted = true
            applyLocationPermissionNeeds()
        default:
            locationManager.delegate = self
            locationManager.requestWhenInUseAuthorization()
        }
    }

    private func locationRelatedSensors() -> [WebhookSensor] {
        webhookSensors.filter { sensor in
            sensorIdsToEnableDisable.map(\.rawValue).contains(sensor.UniqueID)
        }
    }

    private func applyLocationPermissionNeeds() {
        if locationPermissionContext == .shareWithHomeAssistant {
            enableLocationSensor()
        }

        if locationPermissionContext == .secureLocalConnection {
            onboardingServer.update { info in
                info.connection.localAccessSecurityLevel = .mostSecure
            }
        }
    }
}

extension OnboardingPermissionsNavigationViewModel: SensorObserver {
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

extension OnboardingPermissionsNavigationViewModel: CLLocationManagerDelegate {
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

        guard [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.locationPermissionGranted = true
        }

        applyLocationPermissionNeeds()
    }
}
