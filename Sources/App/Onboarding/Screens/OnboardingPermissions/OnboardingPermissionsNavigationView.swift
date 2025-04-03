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
        if let permission = OnboardingPermissionHandler.notDeterminedPermissions.first {
            if permission == .location {
                LocationPermissionView(permission: permission)
            } else {
                // If we endup enforcing other permissions during onboarding
                // we need to handle them here
                flowEnd
            }
        } else {
            flowEnd
        }
    }

    private var flowEnd: some View {
        EmptyView()
            .onAppear {
                Current.onboardingObservation.complete()
            }
    }
}

#Preview {
    OnboardingPermissionsNavigationView()
}
