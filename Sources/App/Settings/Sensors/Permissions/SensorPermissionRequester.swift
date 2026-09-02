import AVFoundation
import Combine
import CoreBluetooth
import CoreMotion
import Foundation
import PromiseKit
import Shared
import Speech
import UIKit
import UserNotifications

/// Reads and requests the device permissions behind the sensors.
///
/// Sensors are opt-in, so switching one on is the only moment the app learns someone wants it, and
/// asking for the permission it needs right then is what keeps a sensor from sitting enabled and
/// silent. Requests are queued: iOS ignores one made while another prompt is on screen, and
/// switching several sensors on at once can need more than one.
@MainActor
final class SensorPermissionRequester {
    static let shared = SensorPermissionRequester()

    private var pending: [SensorPermission] = []
    private var isPrompting = false
    private var didPrompt = false
    private var bluetoothRequester: BluetoothAuthorizationRequester?

    /// Fires after each request resolves, so every screen showing these statuses refreshes. A
    /// subject rather than one callback: the sensor list's badge and the permissions screen both
    /// watch this, and a single slot left whichever registered first hearing nothing.
    let statusDidChange = PassthroughSubject<Void, Never>()

    /// Whether the device can be asked for this permission at all.
    func isAvailable(_ permission: SensorPermission) -> Bool {
        switch permission {
        case .motion:
            return Current.motion.isActivityAvailable()
        case .focus:
            return Current.focusStatus.isAvailable()
        case .location, .notification, .camera, .microphone, .speech, .bluetooth, .localNetwork:
            return true
        }
    }

    /// The status of every permission but notification, which only answers asynchronously.
    func status(for permission: SensorPermission) -> SensorPermissionStatus {
        switch permission {
        case .motion:
            return .init(CMMotionActivityManager.authorizationStatus())
        case .focus:
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
        case .notification, .localNetwork:
            return .unknown
        }
    }

    /// Asks for whatever these sensors need and hasn't been answered yet.
    ///
    /// A permission the user already answered is left alone: iOS won't prompt for it a second time,
    /// and only the Settings app can change it. Nothing happens for sensors that need no permission.
    func requestPermissionsIfNeeded(forSensorUniqueIDs uniqueIDs: [String]) {
        let permissions = Set(uniqueIDs.compactMap(SensorPermission.required(forSensorUniqueID:)))
        for permission in permissions.sorted(by: { $0.rawValue < $1.rawValue }) {
            enqueue(permission)
        }
        promptForNextIfIdle()
    }

    /// Requests one permission on its own, for a screen that asks about them directly.
    func request(_ permission: SensorPermission) {
        enqueue(permission)
        promptForNextIfIdle()
    }

    private func enqueue(_ permission: SensorPermission) {
        guard isAvailable(permission), !pending.contains(permission) else { return }
        guard permission != .localNetwork else { return }
        // Notification is the one permission whose status only answers asynchronously, so there is
        // nothing to check against here; asking for one already answered doesn't prompt again.
        guard permission == .notification || status(for: permission) == .notDetermined else { return }
        pending.append(permission)
    }

    private func promptForNextIfIdle() {
        guard !isPrompting else { return }
        guard let permission = pending.first else {
            // The sensors that were just granted a permission have nothing to report until they
            // are read again, and nothing else asks for that read.
            if didPrompt {
                didPrompt = false
                refreshSensors()
            }
            return
        }
        pending.removeFirst()
        isPrompting = true
        didPrompt = true
        prompt(for: permission) { [weak self] in
            guard let self else { return }
            isPrompting = false
            statusDidChange.send()
            promptForNextIfIdle()
        }
    }

    private func refreshSensors() {
        HomeAssistantAPI.manuallyUpdate(
            applicationState: UIApplication.shared.applicationState,
            // Not `.userRequested`: this follows a permission prompt on its own, and that type also
            // asks for temporary full location accuracy, which has nothing to do with the sensor
            // the user just switched on.
            type: .programmatic
        ).catch { error in
            Current.Log.error("sensor update after a permission request failed: \(error)")
        }
    }

    private func prompt(for permission: SensorPermission, completion: @escaping () -> Void) {
        switch permission {
        case .location, .notification, .motion, .focus:
            guard let type = permissionType(for: permission) else {
                completion()
                return
            }
            type.request { _, _ in
                Task { @MainActor in completion() }
            }
        case .camera:
            AVCaptureDevice.requestAccess(for: .video) { _ in
                Task { @MainActor in completion() }
            }
        case .microphone:
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { _ in
                    Task { @MainActor in completion() }
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { _ in
                    Task { @MainActor in completion() }
                }
            }
        case .speech:
            SFSpeechRecognizer.requestAuthorization { _ in
                Task { @MainActor in completion() }
            }
        case .bluetooth:
            bluetoothRequester = BluetoothAuthorizationRequester {
                Task { @MainActor in completion() }
            }
            bluetoothRequester?.request()
        case .localNetwork:
            completion()
        }
    }

    private func permissionType(for permission: SensorPermission) -> PermissionType? {
        switch permission {
        case .location: return .location
        case .notification: return .notification
        case .motion: return .motion
        case .focus: return .focus
        case .camera, .microphone, .speech, .bluetooth, .localNetwork: return nil
        }
    }
}
