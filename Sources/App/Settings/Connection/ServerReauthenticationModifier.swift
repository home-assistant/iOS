import Shared
import SwiftUI

/// Attaches what a Re-authenticate for `server` presents to the control that starts it: the address
/// picker, the login page, the client certificate import and the failure alert.
struct ServerReauthenticationModifier: ViewModifier {
    @ObservedObject var model: ServerReauthenticationModel
    let server: Server

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                L10n.Settings.ConnectionSection.Reauthenticate.urlPickerTitle,
                isPresented: model.urlPickerBinding(for: server),
                titleVisibility: .visible
            ) {
                ForEach(model.urlTypes(for: server), id: \.self) { urlType in
                    Button(urlType.description) { model.reauthenticate(server, using: urlType) }
                }
                Button(L10n.cancelLabel, role: .cancel, action: {})
            }
            .sheet(item: model.loginBinding(for: server)) { OnboardingAuthLoginView(viewModel: $0, style: .modal) }
            .sheet(item: model.certificateRequestBinding(for: server)) {
                RecoveredServerClientCertificateImportView(request: $0, asSheet: true)
            }
            .background(ClientCertificateImportFormSheet(request: model.certificateFormSheetRequest(for: server)))
            .alert(
                L10n.Settings.ConnectionSection.Reauthenticate.errorTitle,
                isPresented: model.errorBinding(for: server),
                presenting: model.error
            ) { _ in
                Button(L10n.okLabel, role: .cancel, action: {})
            } message: { error in
                Text(error.localizedDescription)
            }
    }
}

extension View {
    func serverReauthentication(_ model: ServerReauthenticationModel, for server: Server) -> some View {
        modifier(ServerReauthenticationModifier(model: model, server: server))
    }
}
