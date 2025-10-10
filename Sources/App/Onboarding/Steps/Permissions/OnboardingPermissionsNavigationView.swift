import Shared
import SwiftUI

struct OnboardingPermissionsNavigationView: View {
    enum Steps {
        case disclaimer
        case location
        case localAccess
        case homeNetwork
    }

    @State private var step: Steps = .disclaimer
    @State private var lastStep: Steps = .disclaimer

    let onboardingServer: Server

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        ZStack {
            switch step {
            case .disclaimer:
                disclaimer
                    .transition(pushTransition)
                    .id(Steps.disclaimer)
                    .zIndex(Double(index(for: .disclaimer)))
            case .location:
                location
                    .transition(pushTransition)
                    .id(Steps.location)
                    .zIndex(Double(index(for: .location)))
            case .localAccess:
                localAccess
                    .transition(pushTransition)
                    .id(Steps.localAccess)
                    .zIndex(Double(index(for: .localAccess)))
            case .homeNetwork:
                homeNetworkInput
                    .transition(pushTransition)
                    .id(Steps.homeNetwork)
                    .zIndex(Double(index(for: .homeNetwork)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .onChange(of: step) { newValue in
            // Update the last step after deciding transition direction
            lastStep = newValue
        }
    }

    private var disclaimer: some View {
        LocalAccessOnlyDisclaimerView {
            step = .location
        }
    }

    private var location: some View {
        LocationPermissionView {
            step = .localAccess
        }
    }
    private var localAccess: some View {
        LocalAccessPermissionView(server: onboardingServer, completeAction: {
            step = .homeNetwork
        })
    }
    private var homeNetworkInput: some View {
        HomeNetworkInputView(onNext: { networkSSID in
            if let networkSSID {
                saveNetworkSSID(networkSSID)
            }
            completeOnboarding()
        }, onSkip: {
            completeOnboarding()
        })
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

    // MARK: - Animation
    // Mimics UINavigationController push/pop animation
    private func index(for step: Steps) -> Int {
        switch step {
        case .disclaimer: return 0
        case .location: return 1
        case .localAccess: return 2
        case .homeNetwork: return 3
        }
    }

    private var isAdvancing: Bool {
        index(for: step) >= index(for: lastStep)
    }

    private var pushTransition: AnyTransition {
        // Respect layout direction (RTL vs LTR)
        let leading: Edge = layoutDirection == .leftToRight ? .leading : .trailing
        let trailing: Edge = layoutDirection == .leftToRight ? .trailing : .leading

        // Forward: insert from trailing, remove to leading (push)
        // Backward: insert from leading, remove to trailing (pop)
        let insertionEdge: Edge = isAdvancing ? trailing : leading
        let removalEdge: Edge = isAdvancing ? leading : trailing

        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }
}

#Preview {
    OnboardingPermissionsNavigationView(onboardingServer: ServerFixture.standard)
}
