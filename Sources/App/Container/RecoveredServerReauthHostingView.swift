import PromiseKit
import Shared
import SwiftUI

/// Hosts the recovered-server re-auth screen via `embeddedInHostingController()` so it gets a
/// `ViewControllerProvider` — the OAuth login is presented from that hosting controller.
struct RecoveredServerReauthHostingView: UIViewControllerRepresentable {
    let server: Server
    let state: OnboardingStateObservable

    func makeUIViewController(context: Context) -> UIViewController {
        RecoveredServerReauthScreen(server: server, state: state).embeddedInHostingController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private struct RecoveredServerReauthScreen: View {
    @EnvironmentObject private var hostingProvider: ViewControllerProvider
    let server: Server
    let state: OnboardingStateObservable

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
                    presenter: hostingProvider.viewController,
                    completion: completion
                )
            },
            serverSelectionAction: { state.handleRecoveredServerSelection($0) }
        )
    }
}
