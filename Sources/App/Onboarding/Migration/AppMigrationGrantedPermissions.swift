import AVFoundation
import CoreBluetooth
import CoreMotion
import Foundation
import Shared
import Speech
import UserNotifications

/// Which device permissions the previous app holds right now, so the new app can ask for exactly
/// those again. iOS grants permissions per bundle, so none of them travel with the setup.
///
/// The statuses come from system daemons, and one of those calls has been seen blocking for minutes
/// while a UI test drove the app. The snapshot therefore runs off the main thread under a fixed
/// budget: if it does not finish in time the transfer goes ahead without it, and the new app simply
/// asks for nothing.
enum AppMigrationGrantedPermissions {
    static let budget: Duration = .seconds(3)

    static func current() async -> [SensorPermission] {
        await withTaskGroup(of: [SensorPermission]?.self) { group in
            group.addTask { await snapshot() }
            group.addTask {
                try? await Task.sleep(for: budget)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            if first == nil {
                Current.Log.error("Permission snapshot did not finish within \(budget); transferring without it")
            }
            return first ?? []
        }
    }

    private static func snapshot() async -> [SensorPermission] {
        var granted: [SensorPermission] = []
        for permission in SensorPermission.allCases {
            let started = Current.date()
            let status = await status(for: permission)
            let elapsed = Current.date().timeIntervalSince(started)
            if elapsed > 1 {
                Current.Log.error("Reading the \(permission.rawValue) permission took \(elapsed)s")
            }
            switch status {
            case .granted, .authorizedAlways, .authorizedWhenInUse:
                granted.append(permission)
            case .notDetermined, .denied, .restricted, .unknown, nil:
                break
            }
        }
        return granted
    }

    /// The same reads `SensorPermissionRequester` does, minus its main-actor requirement. `nil` for
    /// permissions the device cannot hold.
    private static func status(for permission: SensorPermission) async -> SensorPermissionStatus? {
        switch permission {
        case .motion:
            guard Current.motion.isActivityAvailable() else { return nil }
            return .init(CMMotionActivityManager.authorizationStatus())
        case .focus:
            guard Current.focusStatus.isAvailable() else { return nil }
            return .init(Current.focusStatus.authorizationStatus())
        case .location:
            return .init(Current.location.permissionStatus())
        case .camera:
            return .init(AVCaptureDevice.authorizationStatus(for: .video))
        case .microphone:
            if #available(iOS 17.0, *) {
                return .init(AVAudioApplication.shared.recordPermission)
            } else {
                return .init(AVAudioSession.sharedInstance().recordPermission)
            }
        case .speech:
            return .init(SFSpeechRecognizer.authorizationStatus())
        case .bluetooth:
            return .init(CBCentralManager.authorization)
        case .notification:
            return await .init(Current.userNotificationCenter.notificationSettings().authorizationStatus)
        case .localNetwork:
            return nil
        }
    }
}
