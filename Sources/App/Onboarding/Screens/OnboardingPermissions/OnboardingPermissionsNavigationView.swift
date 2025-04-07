import Shared
import SwiftUI

enum OnboardingPermissionHandler {
    static var notDeterminedPermissions: [PermissionType] {
        let permissions: [PermissionType] = [
            .location,
        ]

        return permissions.filter { $0.status == .notDetermined }
    }
}

struct OnboardingPermissionsNavigationView: View {
    var body: some View {
        if let permission = OnboardingPermissionHandler.notDeterminedPermissions.first, permission == .location {
            LocationPermissionView(permission: permission) {
                Current.onboardingObservation.complete()
            }
        } else {
            flowEnd
        }
    }

    private var flowEnd: some View {
        Image(systemSymbol: .checkmark)
            .foregroundStyle(.green)
            .font(.system(size: 100))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    Current.onboardingObservation.complete()
                }
            }
    }
}

#Preview {
    OnboardingPermissionsNavigationView()
}
