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
    let onboardingServer: Server?

    var body: some View {
        Group {
            if let permission = OnboardingPermissionHandler.notDeterminedPermissions.first, permission == .location {
                LocationPermissionView(permission: permission) {
                    Current.onboardingObservation.complete()
                }
            } else {
                flowEnd
            }
        }
        .onDisappear {
            Current.connectivity.syncNetworkInformation {
                if let onboardingServer, let currentSSID = Current.connectivity.currentWiFiSSID() {
                    // Update SSIDs if we have access to them, since we're gonna need it later
                    onboardingServer.info.connection.internalSSIDs = [currentSSID]
                } else {
                    Current.Log.verbose("No onboarding server or no SSID available")
                }
            }
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
    OnboardingPermissionsNavigationView(onboardingServer: ServerFixture.standard)
}
