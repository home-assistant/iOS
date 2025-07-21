import SwiftUI
import Shared
import SFSafeSymbols

struct RemoteAccessView: View {
    @Binding var skipRemoteAccessInput: Bool
    let server: Server
    let urlSetupDone: () -> Void
    @State private var inputExternalURL = false

    var body: some View {
        BaseOnboardingTemplateView(
            icon: {
                Image(.Onboarding.noExternalURL)
            },
            title: L10n.Onboarding.RemoteAccess.title,
            subtitle: L10n.Onboarding.RemoteAccess.subtitle,
            primaryButtonTitle: L10n.Onboarding.RemoteAccess.primaryButton,
            primaryButtonAction: { skipRemoteAccessInput = true },
            secondaryButtonTitle: L10n.Onboarding.RemoteAccess.secondaryButton,
            secondaryButtonAction: { inputExternalURL = true }
        )
        .padding(.top, DesignSystem.Spaces.four) // Compensate the absense of nav bar
        .sheet(isPresented: $inputExternalURL) {
            ManualURLEntryView { url in
                server.update { info in
                    info.connection.set(address: url, for: .external)
                    urlSetupDone()
                }
            }
        }
    }
}

#Preview {
    RemoteAccessView(skipRemoteAccessInput: .constant(false), server: ServerFixture.standard) {
        
    }
}
