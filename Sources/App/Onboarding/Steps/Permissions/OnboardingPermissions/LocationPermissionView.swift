import Shared
import SwiftUI
import SFSafeSymbols

struct LocationPermissionView: View {
    @StateObject private var viewModel = LocationPermissionViewModel()
    let permission: PermissionType
    let completeAction: () -> Void

    var body: some View {

        BaseOnboardingTemplateView(
            icon: {
                Image(systemSymbol: .lockFill)
            },
            title: L10n.Onboarding.LocalAccess.title,
            subtitle: L10n.Onboarding.LocalAccess.body,
            bannerText: L10n.Onboarding.LocalAccess.bannerText,
            primaryButtonTitle: L10n.Onboarding.LocalAccess.primaryButton,
            primaryButtonAction: {
                permission.request { granted, status in

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
    }
}

#Preview {
    LocationPermissionView(permission: .location) {}
}
