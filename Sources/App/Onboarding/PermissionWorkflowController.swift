import Shared
import UIKit

class PermissionWorkflowController {
    private let permissions: [PermissionType]

    init() {
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

        self.permissions = permissions
    }

    func next() -> UIViewController {
        if let permission = permissions.first(where: { $0.status == .notDetermined }) {
            return IndividualPermissionViewController(permission: permission, workflowController: self)
        } else {
            return StoryboardScene.Onboarding.connectInstance.instantiate()
        }
    }
}
