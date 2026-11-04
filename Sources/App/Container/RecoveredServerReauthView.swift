import Shared
import SwiftUI

/// The recovered-server re-auth screen; presents the OAuth login web view as a sheet and feeds its
/// result into `OnboardingStateObservable`'s re-authentication.
struct RecoveredServerReauthView: View {
    @StateObject private var viewModel: RecoveredServerReauthViewModel

    @Environment(\.appSettingsPresenter) private var appSettingsPresenter

    init(server: Server, state: OnboardingStateObservable) {
        self.init(viewModel: RecoveredServerReauthViewModel(server: server, state: state))
    }

    init(viewModel: RecoveredServerReauthViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: viewModel.certificateImportPageBinding) { certificateImportPage }
        }
    }

    @ViewBuilder
    private var certificateImportPage: some View {
        if let request = viewModel.clientCertificateRequest {
            RecoveredServerClientCertificateImportView(request: request, asSheet: false)
        }
    }

    private var content: some View {
        WebViewEmptyStateView(
            style: .recoveredServerNeedingReauthentication,
            server: viewModel.server,
            availableReauthURLTypes: viewModel.availableReauthURLTypes,
            settingsAction: { appSettingsPresenter?.presentSettings() },
            recoveredServerReauthAction: { viewModel.reauthenticate(using: $0, completion: $1) },
            serverSelectionAction: { viewModel.selectServer($0) }
        )
        .sheet(item: $viewModel.loginViewModel) { OnboardingAuthLoginView(viewModel: $0, style: .modal) }
        .sheet(item: viewModel.certificateImportSheetBinding) {
            RecoveredServerClientCertificateImportView(request: $0, asSheet: true)
        }
    }
}

#Preview {
    RecoveredServerReauthView(server: ServerFixture.standard, state: OnboardingStateObservable())
}
