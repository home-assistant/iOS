import Foundation
import Shared

/// A device permission the app can request, listed in `SensorPermissionsView`.
enum SensorPermission: String, CaseIterable, Identifiable {
    case location
    case notification
    case motion
    case focus
    case camera
    case microphone
    case speech
    case bluetooth
    case localNetwork

    var id: String { rawValue }

    var title: String {
        switch self {
        case .location:
            return L10n.SettingsSensors.Permissions.Location.title
        case .notification:
            return L10n.SettingsSensors.Permissions.Notification.title
        case .motion:
            return L10n.SettingsSensors.Permissions.Motion.title
        case .focus:
            return L10n.SettingsSensors.Permissions.Focus.title
        case .camera:
            return L10n.SettingsSensors.Permissions.Camera.title
        case .microphone:
            return L10n.SettingsSensors.Permissions.Microphone.title
        case .speech:
            return L10n.SettingsSensors.Permissions.Speech.title
        case .bluetooth:
            return L10n.SettingsSensors.Permissions.Bluetooth.title
        case .localNetwork:
            return L10n.SettingsSensors.Permissions.LocalNetwork.title
        }
    }

    var usageDescription: String {
        switch self {
        case .location:
            return L10n.SettingsSensors.Permissions.Location.usage
        case .notification:
            return L10n.SettingsSensors.Permissions.Notification.usage
        case .motion:
            return L10n.SettingsSensors.Permissions.Motion.usage
        case .focus:
            return L10n.SettingsSensors.Permissions.Focus.usage
        case .camera:
            return L10n.SettingsSensors.Permissions.Camera.usage
        case .microphone:
            return L10n.SettingsSensors.Permissions.Microphone.usage
        case .speech:
            return L10n.SettingsSensors.Permissions.Speech.usage
        case .bluetooth:
            return L10n.SettingsSensors.Permissions.Bluetooth.usage
        case .localNetwork:
            return L10n.SettingsSensors.Permissions.LocalNetwork.usage
        }
    }

    var icon: MaterialDesignIcons {
        switch self {
        case .location:
            return .mapMarkerOutlineIcon
        case .notification:
            return .bellOutlineIcon
        case .motion:
            return .runIcon
        case .focus:
            return .powerSleepIcon
        case .camera:
            return .cameraIcon
        case .microphone:
            return .microphoneIcon
        case .speech:
            return .microphoneMessageIcon
        case .bluetooth:
            return .bluetoothIcon
        case .localNetwork:
            return .lanIcon
        }
    }
}
