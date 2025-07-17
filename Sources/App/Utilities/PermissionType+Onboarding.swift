import Foundation
import CoreMotion
import Shared

extension PermissionType {
    var status: PermissionStatus {
        Current.onboardingPermissionManager.status(for: self)
    }

    var isAuthorized: Bool {
        switch status {
        case .authorized, .authorizedWhenInUse:
            return true
        case .denied, .notDetermined, .restricted, .unknown:
            return false
        }
    }

    func request(_ completionHandler: @escaping (Bool, PermissionStatus) -> Void) {
        if status == .denied {
            handlePermissionsThatWereDeniedPreviously(completionHandler)
            return
        }

        switch self {
        case .location:
            handleLocationPermissionRequest(completionHandler)
        case .motion:
            handleMotionPermissionRequest(completionHandler)
        case .focus:
            handleFocusPermissionRequest(completionHandler)
        }
    }

    private func handlePermissionsThatWereDeniedPreviously(_ completionHandler: @escaping (Bool, PermissionStatus) -> Void) {
        let destination: UIApplication.OpenSettingsDestination

        switch self {
        case .location: destination = .location
        case .motion: destination = .motion
        case .focus: destination = .focus
        }

        UIApplication.shared.openSettings(destination: destination, completionHandler: nil)
        completionHandler(false, .denied)
    }

    private func handleFocusPermissionRequest(_ completionHandler: @escaping (Bool, PermissionStatus) -> Void) {
        Current.focusStatus.requestAuthorization().done { status in
            completionHandler(status == .authorized, status.genericStatus)
        }
    }

    private func handleLocationPermissionRequest(_ completionHandler: @escaping (Bool, PermissionStatus) -> Void) {
        if PermissionsLocationDelegate.shared == nil {
            PermissionsLocationDelegate.shared = PermissionsLocationDelegate()
        }

        PermissionsLocationDelegate.shared!.requestPermission { status in
            DispatchQueue.main.async {
                completionHandler(status == .authorized || status == .authorizedWhenInUse, status)
                PermissionsLocationDelegate.shared = nil
            }
        }
    }

    private func handleMotionPermissionRequest(_ completionHandler: @escaping (Bool, PermissionStatus) -> Void) {
        let manager = CMMotionActivityManager()
        let now = Date()

        manager.queryActivityStarting(from: now, to: now, to: .main, withHandler: { (_, error: Error?) in
            if let error = error as NSError?,
               error.domain == CMErrorDomain,
               error.code == CMErrorMotionActivityNotAuthorized.rawValue {
                completionHandler(false, .denied)
                return
            }
            completionHandler(true, .authorized)
        })
    }
}
