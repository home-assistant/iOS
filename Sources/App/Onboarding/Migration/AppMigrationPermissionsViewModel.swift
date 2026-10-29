import Combine
import Foundation
import Shared
import UserNotifications

@MainActor
final class AppMigrationPermissionsViewModel: ObservableObject {
    @Published private(set) var statuses: [SensorPermission: SensorPermissionStatus] = [:]

    let permissions: [SensorPermission]

    private let requester = SensorPermissionRequester.shared
    private var cancellables = Set<AnyCancellable>()

    init(permissions: [SensorPermission]) {
        self.permissions = permissions.filter { SensorPermissionRequester.shared.isAvailable($0) }
        requester.statusDidChange
            .sink { [weak self] in
                self?.refresh()
            }
            .store(in: &cancellables)
        refresh()
    }

    func status(for permission: SensorPermission) -> SensorPermissionStatus {
        statuses[permission] ?? .notDetermined
    }

    /// Every permission has been answered one way or the other, so there is nothing left to ask.
    var isSettled: Bool {
        permissions.allSatisfy { status(for: $0) != .notDetermined }
    }

    func refresh() {
        for permission in permissions where permission != .notification {
            statuses[permission] = requester.status(for: permission)
        }
        guard permissions.contains(.notification) else { return }
        Task {
            let settings = await Current.userNotificationCenter.notificationSettings()
            statuses[.notification] = SensorPermissionStatus(settings.authorizationStatus)
        }
    }

    /// Queues every unanswered permission; the requester shows the prompts one after the other.
    func allowAll() {
        for permission in permissions where status(for: permission) == .notDetermined {
            requester.request(permission)
        }
    }

    func handleTap(on permission: SensorPermission) {
        guard status(for: permission) == .notDetermined else {
            URLOpener.shared.openSettings(destination: permission.settingsDestination, completionHandler: nil)
            return
        }
        requester.request(permission)
    }
}
