import SFSafeSymbols
import Shared
import SwiftUI

/// Asks whether a server reporting an instance ID the app already knows, at an address it does
/// not, replaces that server or is added next to it. Presented as a sheet on iOS and pushed onto
/// the onboarding stack on Mac Catalyst; cancelling ends the auth flow.
struct OnboardingServerIdentityView: View {
    let request: OnboardingServerIdentityRequest

    var body: some View {
        BaseOnboardingView(
            illustration: {
                Image(systemSymbol: .serverRack)
                    .font(.system(size: 64))
                    .foregroundStyle(.haPrimary)
            },
            title: L10n.Onboarding.ServerIdentity.title,
            primaryDescription: L10n.Onboarding.ServerIdentity.body(
                request.newServer.name,
                request.existingServer.name
            ),
            content: {
                NavigationLink(L10n.Onboarding.ServerIdentity.why) {
                    ServerIdentityExplanationView(conflictingServers: [[request.newServer, request.existingServer]])
                }
                .font(DesignSystem.Font.body)
                .accessibilityIdentifier(AccessibilityIdentifier.onboardingServerIdentityWhy.rawValue)
            },
            primaryActionTitle: L10n.Onboarding.ServerIdentity.addSeparate,
            primaryAction: request.addAsSeparateServer,
            primaryActionIdentifier: AccessibilityIdentifier.onboardingServerIdentityAddSeparate.rawValue,
            secondaryActionTitle: L10n.Onboarding.ServerIdentity.replace(request.existingServer.name),
            secondaryAction: request.replaceExistingServer,
            secondaryActionIdentifier: AccessibilityIdentifier.onboardingServerIdentityReplace.rawValue
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.cancelLabel, action: request.cancel)
            }
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingServerIdentityView(request: OnboardingServerIdentityRequest(
            newServer: ServerIdentityConflictingServer(name: "Chalet", address: "http://chalet.example.com:8123"),
            existingServer: ServerIdentityConflictingServer(name: "Home", address: "http://homeassistant.local:8123"),
            onDecision: { _ in },
            onCancel: {}
        ))
    }
}
