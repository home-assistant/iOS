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

    // Tracks if user skipped/added manually remote access input
    @State private var skipOrAddedRemoteAccessInput = false
    @State private var navigationBarBackButtonHidden = true

    // This keeps track of if the user had a remote connection when the screen appeared and differentiate from
    // the case when it adds the remote url afterwards
    @State private var hadRemoteConnectionWhenTheScreenAppeared: Bool?

    init(onboardingServer: Server?) {
        self.onboardingServer = onboardingServer
    }

    var body: some View {
        content
            .navigationBarBackButtonHidden(navigationBarBackButtonHidden)
            .interactiveDismissDisabled(navigationBarBackButtonHidden)
            .onDisappear {
                if Current.location.permissionStatus == .denied {
                    useLocalConnectionAsRemoteIfNeeded()
                } else {
                    addCurrentSSIDAsLocalConnectionSafeNetwork()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        permissionsFlow
            .onAppear {
                // Prevent going back to servers list, server is onboarded until manually removed
                navigationBarBackButtonHidden = true
            }
            .onDisappear {
                // Allow subsequent screens to have back button
                navigationBarBackButtonHidden = false
            }
    }

    @ViewBuilder
    private var permissionsFlow: some View {
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

    // Since user gave location access we can use it's current network SSID as Home identifier
    private func addCurrentSSIDAsLocalConnectionSafeNetwork() {
        Current.connectivity.syncNetworkInformation {
            if let onboardingServer, let currentSSID = Current.connectivity.currentWiFiSSID() {
                // Update SSIDs if we have access to them, since we're gonna need it later
                onboardingServer.info.connection.internalSSIDs = [currentSSID]
            } else {
                Current.Log.verbose("No onboarding server or no SSID available")
            }
        }
    }

    /* If the app can't determine user location and user does not have remote connection configured
     the app will use the local IP as remote access. */
    private func useLocalConnectionAsRemoteIfNeeded() {
        if onboardingServer?.info.connection.address(for: .external) == nil,
           onboardingServer?.info.connection.address(for: .remoteUI) == nil {
            onboardingServer?.update { serverInfo in
                serverInfo.connection.set(address: serverInfo.connection.internalURL, for: .external)
                serverInfo.connection.set(address: nil, for: .internal)
            }
        }
    }
}

#Preview {
    OnboardingPermissionsNavigationView(onboardingServer: ServerFixture.standard)
}
