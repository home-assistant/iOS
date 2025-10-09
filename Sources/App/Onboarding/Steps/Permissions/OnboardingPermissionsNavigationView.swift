import Shared
import SwiftUI

struct OnboardingPermissionsNavigationView: View {
    let onboardingServer: Server
    @State private var showLocalAccessChoices = false
    @State private var showHomeNetworkConfiguration = false

    var body: some View {
        NavigationView {
            VStack {
                location
                localAccessNavigationLink
            }
        }
        .navigationViewStyle(.stack)
        .navigationBarHidden(true)
    }

    private var location: some View {
        LocationPermissionView {
            guard !showLocalAccessChoices else { return }
            showLocalAccessChoices = true
        }
    }

    private var localAccessNavigationLink: some View {
        NavigationLink("", isActive: $showLocalAccessChoices) {
            VStack {
                LocalAccessPermissionView(server: onboardingServer, completeAction: {
                    showHomeNetworkConfiguration = true
                })
                homeNetworkInputNavigationLink
            }
        }
    }

    private var homeNetworkInputNavigationLink: some View {
        NavigationLink("", isActive: $showHomeNetworkConfiguration) {
            HomeNetworkInputView(onNext: { networkSSID in
                if let networkSSID {
                    saveNetworkSSID(networkSSID)
                }
                completeOnboarding()
            }, onSkip: {
                completeOnboarding()
            })
        }
    }

    private func saveNetworkSSID(_ ssid: String) {
        onboardingServer.update { info in
            info.connection.internalSSIDs = [ssid]
        }
    }

    private func completeOnboarding() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            Current.onboardingObservation.complete()
        }
    }

    // Since user gave location access we can use it's current network SSID as Home identifier
    private func addCurrentSSIDAsLocalConnectionSafeNetwork() {
        Current.connectivity.syncNetworkInformation {
            if let currentSSID = Current.connectivity.currentWiFiSSID() {
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
        if onboardingServer.info.connection.address(for: .external) == nil,
           onboardingServer.info.connection.address(for: .remoteUI) == nil {
            onboardingServer.update { serverInfo in
                serverInfo.connection.set(address: serverInfo.connection.internalURL, for: .external)
                serverInfo.connection.set(address: nil, for: .internal)
            }
        }
    }
}

#Preview {
    OnboardingPermissionsNavigationView(onboardingServer: ServerFixture.standard)
}
