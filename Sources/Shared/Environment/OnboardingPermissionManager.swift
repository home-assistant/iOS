import Foundation
import CoreLocation
import CoreMotion

public protocol OnboardingPermissionManagerProtocol {
    func status(for permissionType: PermissionType) -> PermissionStatus
}

internal final class OnboardingPermissionManager: OnboardingPermissionManagerProtocol {

    func status(for permissionType: PermissionType) -> PermissionStatus {
        switch permissionType {
        case .location:
            let locationManager = CLLocationManager()
            return locationManager.authorizationStatus.genericStatus
        case .motion:
            return CMMotionActivityManager.authorizationStatus().genericStatus
        case .focus:
            return Current.focusStatus.authorizationStatus().genericStatus
        }
    }
}
