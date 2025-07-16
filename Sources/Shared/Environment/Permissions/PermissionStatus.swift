import Foundation

public enum PermissionStatus {
    case notDetermined
    case denied
    case authorized
    case authorizedWhenInUse // CLAuthorizationStatus only
    case restricted // Used if UNAuthorizationStatus is .provisional
    case unknown

    public var description: String {
        switch self {
        case .notDetermined:
            return "Not determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .authorizedWhenInUse:
            return "Authorized when in use"
        case .unknown:
            return "Unknown"
        }
    }
}
