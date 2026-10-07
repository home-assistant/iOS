import AVFoundation
import CoreBluetooth
import CoreLocation
import CoreMotion
import Foundation
import Shared
import Speech
import SwiftUI
import UserNotifications

/// The state of a `SensorPermission` as reported by the system.
enum SensorPermissionStatus: Equatable {
    case notDetermined
    case granted
    case authorizedAlways
    case authorizedWhenInUse
    case denied
    case restricted
    /// The system exposes no way to read this permission (e.g. Local Network).
    case unknown

    var description: String {
        switch self {
        case .notDetermined:
            return L10n.SettingsSensors.Permissions.Status.notRequested
        case .granted:
            return L10n.SettingsSensors.Permissions.Status.granted
        case .authorizedAlways:
            return L10n.SettingsSensors.Permissions.Status.always
        case .authorizedWhenInUse:
            return L10n.SettingsSensors.Permissions.Status.whileInUse
        case .denied:
            return L10n.SettingsSensors.Permissions.Status.denied
        case .restricted:
            return L10n.SettingsSensors.Permissions.Status.restricted
        case .unknown:
            return ""
        }
    }

    var color: Color {
        switch self {
        case .granted, .authorizedAlways, .authorizedWhenInUse:
            return .green
        case .denied, .restricted:
            return .yellow
        case .notDetermined, .unknown:
            return .secondary
        }
    }
}

extension SensorPermissionStatus {
    init(_ status: CMAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .authorized: self = .granted
        @unknown default: self = .notDetermined
        }
    }

    init(_ status: FocusStatusWrapper.AuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .authorized: self = .granted
        }
    }

    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .authorizedAlways: self = .authorizedAlways
        case .authorizedWhenInUse: self = .authorizedWhenInUse
        @unknown default: self = .notDetermined
        }
    }

    init(_ status: AVAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .authorized: self = .granted
        @unknown default: self = .notDetermined
        }
    }

    @available(iOS 17.0, *)
    init(_ status: AVAudioApplication.recordPermission) {
        switch status {
        case .undetermined: self = .notDetermined
        case .denied: self = .denied
        case .granted: self = .granted
        @unknown default: self = .notDetermined
        }
    }

    init(_ status: AVAudioSession.RecordPermission) {
        switch status {
        case .undetermined: self = .notDetermined
        case .denied: self = .denied
        case .granted: self = .granted
        @unknown default: self = .notDetermined
        }
    }

    init(_ status: SFSpeechRecognizerAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .authorized: self = .granted
        @unknown default: self = .notDetermined
        }
    }

    init(_ status: CBManagerAuthorization) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .allowedAlways: self = .granted
        @unknown default: self = .notDetermined
        }
    }

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .authorized, .provisional, .ephemeral: self = .granted
        @unknown default: self = .notDetermined
        }
    }
}
