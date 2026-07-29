import AVFoundation
import Combine
import CoreBluetooth
import CoreLocation
import CoreMotion
import Foundation
import PromiseKit
import Shared
import Speech
import UserNotifications

@MainActor
final class SensorPermissionsViewModel: ObservableObject {
    @Published private(set) var statuses: [SensorPermission: SensorPermissionStatus] = [:]
    @Published var alertMessage: String?
    @Published var showAlert = false

    private var bluetoothRequester: BluetoothAuthorizationRequester?

    var availablePermissions: [SensorPermission] {
        SensorPermission.allCases.filter { permission in
            switch permission {
            case .motion:
                return Current.motion.isActivityAvailable()
            case .focus:
                return Current.focusStatus.isAvailable()
            case .location, .notification, .camera, .microphone, .speech, .bluetooth, .localNetwork:
                return true
            }
        }
    }

    /// How many permissions were never requested, used as the badge of the permissions row.
    var notDeterminedCount: Int {
        availablePermissions.filter { status(for: $0) == .notDetermined }.count
    }

    init() {
        update()
    }

    func status(for permission: SensorPermission) -> SensorPermissionStatus {
        statuses[permission] ?? .notDetermined
    }

    func update() {
        var updatedStatuses: [SensorPermission: SensorPermissionStatus] = [:]
        for permission in availablePermissions where permission != .notification {
            updatedStatuses[permission] = synchronousStatus(for: permission)
        }
        statuses = updatedStatuses
        refreshNotificationStatus()
    }

    /// Requests a permission that was never answered, otherwise sends the user to system settings,
    /// the only place an already-answered permission can be changed.
    func handleTap(on permission: SensorPermission) {
        guard status(for: permission) == .notDetermined else {
            openSettings(for: permission)
            return
        }
        request(permission)
    }

    // MARK: - Status

    private func synchronousStatus(for permission: SensorPermission) -> SensorPermissionStatus {
        switch permission {
        case .motion:
            return .init(CMMotionActivityManager.authorizationStatus())
        case .focus:
            return .init(Current.focusStatus.authorizationStatus())
        case .location:
            return .init(CLLocationManager().authorizationStatus)
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
            return status(for: .notification)
        case .localNetwork:
            return .unknown
        }
    }

    private func refreshNotificationStatus() {
        guard availablePermissions.contains(.notification) else { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let status = SensorPermissionStatus(settings.authorizationStatus)
            Task { @MainActor in
                self?.statuses[.notification] = status
            }
        }
    }

    // MARK: - Requesting

    private func request(_ permission: SensorPermission) {
        switch permission {
        case .location, .notification, .motion, .focus:
            requestViaPermissionType(for: permission)
        case .camera:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                Task { @MainActor in self?.update() }
            }
        case .microphone:
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { [weak self] _ in
                    Task { @MainActor in self?.update() }
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { [weak self] _ in
                    Task { @MainActor in self?.update() }
                }
            }
        case .speech:
            SFSpeechRecognizer.requestAuthorization { [weak self] _ in
                Task { @MainActor in self?.update() }
            }
        case .bluetooth:
            bluetoothRequester = BluetoothAuthorizationRequester { [weak self] in
                Task { @MainActor in self?.update() }
            }
            bluetoothRequester?.request()
        case .localNetwork:
            openSettings(for: permission)
        }
    }

    private func requestViaPermissionType(for permission: SensorPermission) {
        guard let type = permissionType(for: permission) else { return }
        type.request { [weak self] _, _ in
            Task { @MainActor in self?.update() }
        }
    }

    // MARK: - Settings

    private func openSettings(for permission: SensorPermission) {
        URLOpener.shared.openSettings(destination: settingsDestination(for: permission), completionHandler: nil)
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

    private func settingsDestination(for permission: SensorPermission) -> OpenSettingsDestination {
        switch permission {
        case .location: return .location
        case .notification: return .notification
        case .motion: return .motion
        case .focus: return .focus
        case .camera: return .camera
        case .microphone: return .microphone
        case .speech: return .speech
        case .bluetooth: return .bluetooth
        case .localNetwork: return .localNetwork
        }
    }
}

/// Instantiating a `CBCentralManager` is what surfaces the Bluetooth prompt; the delegate callback
/// reports the outcome so the list can refresh.
private final class BluetoothAuthorizationRequester: NSObject, CBCentralManagerDelegate {
    private var manager: CBCentralManager?
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        super.init()
    }

    func request() {
        manager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        onChange()
    }
}
