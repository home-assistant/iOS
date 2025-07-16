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
                Image(systemSymbol: .globe)
            },
            title: "Access outside your home",
            subtitle: "If you are interested in logging in to Home Assistant installation while away, you will have to make your instance remotely accessible. You can set this up in your Home Assistant instance.\n\nRight now, you can only connect while on your home network.",
            primaryButtonTitle: "Skip for now",
            primaryButtonAction: { skipRemoteAccessInput = true },
            secondaryButtonTitle: "I know my external URL",
            secondaryButtonAction: { inputExternalURL = true }
        )
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
