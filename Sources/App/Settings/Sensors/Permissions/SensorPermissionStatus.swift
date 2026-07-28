import CoreMotion
import Foundation
import Shared

/// The state of a `SensorPermission` as reported by the system.
enum SensorPermissionStatus: Equatable {
    /// The user was never asked for this permission, so it can still be requested in app.
    case notDetermined
    case granted
    case denied
    case restricted
    /// The permission was already requested, but the system doesn't disclose the outcome.
    case requested

    var description: String {
        switch self {
        case .notDetermined:
            return L10n.SettingsSensors.Permissions.Status.notRequested
        case .granted:
            return L10n.SettingsSensors.Permissions.Status.granted
        case .denied:
            return L10n.SettingsSensors.Permissions.Status.denied
        case .restricted:
            return L10n.SettingsSensors.Permissions.Status.restricted
        case .requested:
            return L10n.SettingsSensors.Permissions.Status.requested
        }
    }
}

extension SensorPermissionStatus {
    init(_ status: CMAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorized:
            self = .granted
        @unknown default:
            self = .notDetermined
        }
    }

    init(_ status: FocusStatusWrapper.AuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorized:
            self = .granted
        @unknown default:
            self = .notDetermined
        }
    }
}
