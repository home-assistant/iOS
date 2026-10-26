import Shared
import SwiftUI

/// The internal or external URL editor as the server details screen presents it: in a sheet that zooms
/// out of the pill that opened it and closes back into the view model's flag.
struct ServerURLEditorSheet: View {
    @ObservedObject var viewModel: ConnectionSettingsViewModel
    let urlType: ConnectionInfo.URLType
    let transitionNamespace: Namespace.ID?
    @State private var isSaving = false

    var body: some View {
        ServerSettingsSheet(
            zoomSourceID: urlType == .internal ? .internalURL : .externalURL,
            transitionNamespace: transitionNamespace,
            onClose: {
                viewModel.isEditingInternalURL = false
                viewModel.isEditingExternalURL = false
            },
            isCloseDisabled: isSaving
        ) {
            ConnectionURLView(server: viewModel.server, urlType: urlType, isSaving: $isSaving)
        }
    }
}

#Preview {
    ServerURLEditorSheet(
        viewModel: ConnectionSettingsViewModel(server: ServerFixture.standard),
        urlType: .internal,
        transitionNamespace: nil
    )
}
