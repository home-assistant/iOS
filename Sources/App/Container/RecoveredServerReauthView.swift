import PromiseKit
import Shared
import SwiftUI

/// The recovered-server re-auth screen; presents the OAuth login web view as a sheet and feeds its
/// result into `OnboardingStateObservable`'s re-authentication.
struct RecoveredServerReauthView: View {
    let server: Server
    let state: OnboardingStateObservable

    @Environment(\.appSettingsPresenter) private var appSettingsPresenter

    @State private var loginViewModel: OnboardingAuthLoginViewModel?
    @State private var clientCertificateRequest: OnboardingClientCertificateRequest?

    var body: some View {
        WebViewEmptyStateView(
            style: .recoveredServerNeedingReauthentication,
            server: server,
            availableReauthURLTypes: state.availableReauthURLTypes(for: server),
            settingsAction: { appSettingsPresenter?.presentSettings() },
            recoveredServerReauthAction: { urlType, completion in
                state.performRecoveredServerReauthentication(
                    for: server,
                    using: urlType,
                    login: { authDetails in
                        let viewModel = OnboardingAuthLoginViewModel(authDetails: authDetails)
                        loginViewModel = viewModel
                        return viewModel.resultPromise.ensure {
                            loginViewModel = nil
                        }
                    },
                    importClientCertificate: {
                        Promise { seal in
                            clientCertificateRequest = OnboardingClientCertificateRequest(
                                onImport: { certificate in
                                    clientCertificateRequest = nil
                                    seal.fulfill(certificate)
                                },
                                onCancel: {
                                    clientCertificateRequest = nil
                                    seal.reject(PMKError.cancelled)
                                }
                            )
                        }
                    },
                    completion: completion
                )
            },
            serverSelectionAction: { state.handleRecoveredServerSelection($0) }
        )
        .sheet(item: $loginViewModel) { viewModel in
            OnboardingAuthLoginView(viewModel: viewModel, style: .modal)
        }
        .sheet(item: $clientCertificateRequest) { request in
            NavigationView {
                ClientCertificateOnboardingView(
                    onImport: { request.complete(with: $0) },
                    onCancel: { request.cancel() }
                )
            }
            .navigationViewStyle(.stack)
            .presentationDetents([.medium])
            .onDisappear {
                request.cancel()
            }
        }
    }
}

#Preview {
    RecoveredServerReauthView(server: ServerFixture.standard, state: OnboardingStateObservable())
}
