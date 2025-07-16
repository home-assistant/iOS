import Foundation

public extension FocusStatusWrapper.AuthorizationStatus {
    public var genericStatus: PermissionStatus {
        switch self {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        }
    }
}
