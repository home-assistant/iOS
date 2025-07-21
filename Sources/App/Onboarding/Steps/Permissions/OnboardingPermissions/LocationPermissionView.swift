import Shared
import SwiftUI
import SFSafeSymbols

struct LocationPermissionView: View {
    @StateObject private var viewModel = LocationPermissionViewModel()
    @State private var showLocationSharingScreen = false
    let permission: PermissionType
    let completeAction: () -> Void

    var body: some View {
        Group {
            BaseOnboardingTemplateView(
                icon: {
                    Image(.Onboarding.localAccess)
                },
                title: L10n.Onboarding.LocalAccess.title,
                subtitle: L10n.Onboarding.LocalAccess.body,
                bannerText: L10n.Onboarding.LocalAccess.bannerText,
                primaryButtonTitle: L10n.Onboarding.LocalAccess.primaryButton,
                primaryButtonAction: {
                    permission.request { granted, status in
                        switch status {
                        case .authorized, .authorizedWhenInUse:
                            showLocationSharingScreen = true
                        default: break
                            // warn what will happen if not granted
                        }
                    }
                },
                secondaryButtonTitle: L10n.Onboarding.LocalAccess.secondaryButton,
                secondaryButtonAction: {

                }
            )
            .onChange(of: viewModel.shouldComplete) { newValue in
                if newValue {
                    completeAction()
                }
            }

            NavigationLink("", isActive: $showLocationSharingScreen) {
                LocationSharingView(permission: permission) {
                    completeAction()
                }
            }
        }
    }
}

#Preview {
    LocationPermissionView(permission: .location) {}
}

struct LocationSharingView: View {
    @StateObject private var viewModel = LocationPermissionViewModel()
    let permission: PermissionType
    let completeAction: () -> Void

    var body: some View {
        Group {
            BaseOnboardingTemplateView(
                icon: {
                    Image(.Onboarding.locationAccess)
                },
                title: L10n.Onboarding.LocalAccess.title,
                subtitle: L10n.Onboarding.LocalAccess.body,
                bannerText: L10n.Onboarding.LocalAccess.bannerText,
                primaryButtonTitle: L10n.Onboarding.LocalAccess.primaryButton,
                primaryButtonAction: {
                    completeAction()
                },
                secondaryButtonTitle: L10n.Onboarding.LocalAccess.secondaryButton,
                secondaryButtonAction: {

                }
            )
            .onChange(of: viewModel.shouldComplete) { newValue in
                if newValue {
                    completeAction()
                }
            }
        }
    }
}
