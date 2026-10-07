import Combine
import Foundation
import Shared
import UserNotifications

@MainActor
final class SensorPermissionsViewModel: ObservableObject {
    @Published private(set) var statuses: [SensorPermission: SensorPermissionStatus] = [:]
    @Published var alertMessage: String?
    @Published var showAlert = false

    private let requester = SensorPermissionRequester.shared
    private var cancellables = Set<AnyCancellable>()

    var availablePermissions: [SensorPermission] {
        SensorPermission.allCases.filter { requester.isAvailable($0) }
    }

    /// How many permissions were never requested, used as the badge of the permissions row.
    var notDeterminedCount: Int {
        availablePermissions.filter { status(for: $0) == .notDetermined }.count
    }

    init() {
        requester.statusDidChange
            .sink { [weak self] in
                self?.update()
            }
            .store(in: &cancellables)
        update()
    }

    func status(for permission: SensorPermission) -> SensorPermissionStatus {
        statuses[permission] ?? .notDetermined
    }

    func update() {
        var updatedStatuses: [SensorPermission: SensorPermissionStatus] = [:]
        for permission in availablePermissions where permission != .notification {
            updatedStatuses[permission] = requester.status(for: permission)
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
        requester.request(permission)
    }

    // MARK: - Status

    private func refreshNotificationStatus() {
        guard availablePermissions.contains(.notification) else { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let status = SensorPermissionStatus(settings.authorizationStatus)
            Task { @MainActor in
                self?.statuses[.notification] = status
            }
        }
    }

    // MARK: - Settings

    private func openSettings(for permission: SensorPermission) {
        URLOpener.shared.openSettings(destination: settingsDestination(for: permission), completionHandler: nil)
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
