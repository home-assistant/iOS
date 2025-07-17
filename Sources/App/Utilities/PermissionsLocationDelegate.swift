import Foundation
import CoreLocation
import Shared

final class PermissionsLocationDelegate: NSObject, CLLocationManagerDelegate {
    static var shared: PermissionsLocationDelegate?

    lazy var locationManager: CLLocationManager = .init()

    typealias LocationPermissionCompletionBlock = (PermissionStatus) -> Void
    var completionHandler: LocationPermissionCompletionBlock?

    override init() {
        super.init()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .notDetermined {
            return
        }

        if manager.authorizationStatus == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }

        completionHandler?(manager.authorizationStatus.genericStatus)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .notDetermined {
            return
        }

        completionHandler?(status.genericStatus)
    }

    func requestPermission(_ completionHandler: @escaping LocationPermissionCompletionBlock) {
        self.completionHandler = completionHandler

        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            locationManager.delegate = self
            locationManager.requestWhenInUseAuthorization()
        default:
            completionHandler(status.genericStatus)
        }
    }

    var isAuthorized: Bool {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        case .denied, .notDetermined, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    deinit {
        locationManager.delegate = nil
    }
}
