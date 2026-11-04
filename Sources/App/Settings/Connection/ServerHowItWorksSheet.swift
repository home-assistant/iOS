import Shared
import SwiftUI

/// The "Understand Internal vs External URLs" explainer as the Troubleshooting button presents it:
/// in a sheet that closes back into the view model's flag.
struct ServerHowItWorksSheet: View {
    @ObservedObject var viewModel: ConnectionSettingsViewModel

    var body: some View {
        ServerSettingsSheet(
            zoomSourceID: nil,
            transitionNamespace: nil,
            onClose: { viewModel.isShowingHowItWorks = false }
        ) {
            ConnectionURLsHowItWorksView(server: viewModel.server)
        }
    }
}

#Preview {
    ServerHowItWorksSheet(viewModel: ConnectionSettingsViewModel(server: ServerFixture.standard))
}
