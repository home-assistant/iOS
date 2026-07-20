import PromiseKit
import Shared
import SwiftUI

/// The recovered-server re-auth screen; presents the OAuth login web view as a sheet and feeds its
/// result into `OnboardingStateObservable`'s re-authentication.
struct RecoveredServerReauthView: View {
    let server: Server
    let state: OnboardingStateObservable

    @State private var loginViewModel: OnboardingAuthLoginViewModel?

    var body: some View {
        WebViewEmptyStateView(
            style: .recoveredServerNeedingReauthentication,
            server: server,
            availableReauthURLTypes: state.availableReauthURLTypes(for: server),
            settingsAction: { Current.sceneManager.appCoordinator.done { $0.showSettings() } },
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
                    completion: completion
                )
            },
            serverSelectionAction: { state.handleRecoveredServerSelection($0) }
        )
        .sheet(item: $loginViewModel) { viewModel in
            OnboardingAuthLoginView(viewModel: viewModel, style: .modal)
        }
    }
}

#Preview {
    RecoveredServerReauthView(server: ServerFixture.standard, state: OnboardingStateObservable())
}
