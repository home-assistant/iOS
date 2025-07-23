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
    private let onboardingServer: Server
    @StateObject private var viewModel: OnboardingPermissionsNavigationViewModel
    // Tracks if user skipped/added manually remote access input
    @State private var skipOrAddedRemoteAccessInput = false
    @State private var navigationBarBackButtonHidden = true

    // Navigation
    @State private var showLocalAccessPermissionsView = false

    // This keeps track of if the user had a remote connection when the screen appeared and differentiate from
    // the case when it adds the remote url afterwards
    @State private var hadRemoteConnectionWhenTheScreenAppeared: Bool?

    init(onboardingServer: Server) {
        self.onboardingServer = onboardingServer
        self._viewModel = StateObject(wrappedValue: OnboardingPermissionsNavigationViewModel(onboardingServer: onboardingServer))
    }

    var body: some View {
        content
            .navigationBarBackButtonHidden(navigationBarBackButtonHidden)
            .interactiveDismissDisabled(navigationBarBackButtonHidden)
    }

    @ViewBuilder
    private var content: some View {
        VStack {
            LocationSharingView(permission: .location) {
                if [.authorizedAlways, .authorizedWhenInUse].contains(Current.location.permissionStatus) || onboardingServer.info.connection.hasRemoteConnection {

                    viewModel.addCurrentSSIDAsLocalConnectionSafeNetwork {
                        // Skip local access permissions if user already has remote access configured or if location is already authorized and we can auto configure
                        completeOnboarding()
                    }
                } else {
                    showLocalAccessPermissionsView = true
                }
            } secondaryButtonAction: {
                showLocalAccessPermissionsView = true
            }
            NavigationLink(destination: LocalAccessPermissionView(onboardingServer: onboardingServer, permission: .location, primaryButtonAction: {
                viewModel.addCurrentSSIDAsLocalConnectionSafeNetwork {
                    completeOnboarding()
                }
            }, secondaryButtonAction: {
                
            }), isActive: $showLocalAccessPermissionsView) {
                EmptyView()
            }
        }
        .onAppear {
            // Prevent going back to servers list, server is onboarded until manually removed
            navigationBarBackButtonHidden = true
        }
        .onDisappear {
            // Allow subsequent screens to have back button
            navigationBarBackButtonHidden = false
        }
    }

    private func completeOnboarding() {
        Current.onboardingObservation.complete()
    }
}

#Preview {
    OnboardingPermissionsNavigationView(onboardingServer: ServerFixture.standard)
}
