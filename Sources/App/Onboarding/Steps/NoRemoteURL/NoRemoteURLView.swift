import SwiftUI
import Shared

struct NoRemoteURLView: View {
    let onboardingServer: Server

    var body: some View {
        BaseOnboardingTemplateView(
            icon: {
                Image(.Onboarding.noExternalURL)
            },
            title: L10n.Onboarding.NoRemoteURL.title,
            subtitle: L10n.Onboarding.NoRemoteURL.subtitle,
            primaryButtonTitle: L10n.Onboarding.NoRemoteURL.primaryButton,
            primaryButtonDestination: {
                OnboardingPermissionsNavigationView(onboardingServer: onboardingServer)
            }
        )
        .interactiveDismissDisabled(true)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    NoRemoteURLView(onboardingServer: ServerFixture.standard)
}
