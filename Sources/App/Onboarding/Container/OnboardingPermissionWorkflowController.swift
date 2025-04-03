import Shared
import UIKit

enum OnboardingPermissionHandler {
    static var notDeterminedPermissions: [PermissionType] {
        var permissions: [PermissionType] = [
            //            .location,
        ]

        return permissions.filter { $0.status == .notDetermined }
    }
}
