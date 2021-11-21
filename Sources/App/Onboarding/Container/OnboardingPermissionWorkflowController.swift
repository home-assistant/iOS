import Shared
import UIKit

class OnboardingPermissionViewControllerFactory {
    static var hasControllers: Bool {
        !permissions.isEmpty
    }

    static func next(server: Server?) -> UIViewController {
        if let permission = permissions.first {
            return OnboardingPermissionViewController(server: server, permission: permission, factory: self)
        } else {
            return OnboardingTerminalViewController()
        }
    }

    private static var permissions: [PermissionType] {
        var permissions: [PermissionType] = [
            .notification,
            .location,
        ]

        if Current.motion.isActivityAvailable() {
            permissions.append(.motion)
        }

        if Current.focusStatus.isAvailable() {
            permissions.append(.focus)
        }

        return permissions.filter { $0.status == .notDetermined }
    }
}
