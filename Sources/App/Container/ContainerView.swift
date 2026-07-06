import PromiseKit
import Shared
import SwiftUI
import UIKit

/// Presents app Settings from above the kiosk/container swap (hosted by `ConditionalContainerView`) so that
/// toggling kiosk mode — reachable via Settings → Kiosk — doesn't tear the Settings sheet down with the
/// container it would otherwise be presented from.
final class AppSettingsPresenter: ObservableObject {
    static let shared = AppSettingsPresenter()
    @Published var isPresented = false
    private init() {}
}

struct ContainerView: View {
    @StateObject private var state = OnboardingStateObservable()
    @StateObject private var viewModel = ContainerViewModel()
    @State private var coordinator = AppContainerCoordinator()

    var body: some View {
        Group {
            switch state.screen {
            case let .onboarding(style):
                // Host onboarding via `embeddedInHostingController()` (inside `OnboardingHostingView`): the
                // flow reads an `@EnvironmentObject ViewControllerProvider` (e.g. `OnboardingServersListView`,
                // to present the OAuth flow) that the SwiftUI `WindowGroup` does not inject — a direct render
                // would crash on first access. `.id(style)` rebuilds the controller if the style changes.
                OnboardingHostingView(onboardingStyle: style)
                    .id(style)
            case let .webView(server):
                HomeAssistantView(server: server) { webViewController in
                    coordinator.setFrontend(webViewController)
                    Current.sceneManager.setWebViewController(webViewController)
                }
                .id(server.identifier.rawValue)
            case .recoveredServerImport:
                RecoveredServersImportView(onImport: { state.completeRecoveredServerImport() })
            case let .recoveredServerReauth(server):
                RecoveredServerReauthHostingView(server: server, state: state)
            }
        }
        .navigationTitle(" ") // Remove default macOS title
        .onAppear {
            coordinator.onOpenServer = { state.showWebView(for: $0) }
            coordinator.onSetup = { state.reevaluate() }
            coordinator.onShowSettings = { AppSettingsPresenter.shared.isPresented = true }
            coordinator.onShowAssistSettings = { viewModel.presentAssistSettings() }
            coordinator.onShowDownloadManager = { viewModel.presentDownloadManager($0) }
            coordinator.onShowOnboardingPermissions = { viewModel.presentOnboardingPermissions(server: $0, steps: $1) }
            coordinator.onSelectServer = { prompt, includeSettings in
                viewModel.presentServerSelect(prompt: prompt, includeSettings: includeSettings) {
                    coordinator.completeServerSelection($0)
                }
            }
            Current.sceneManager.registerAppCoordinator(coordinator)
            viewModel.presentLaunchMessagesIfNeeded(isShowingWebView: isShowingWebView)
        }
        .onChange(of: state.screen) { _ in
            viewModel.presentLaunchMessagesIfNeeded(isShowingWebView: isShowingWebView)
        }
        .sheet(item: $viewModel.presentedSheet, onDismiss: { viewModel.showNextLaunchMessage() }) { sheet in
            switch sheet {
            case let .whatsNew(release):
                WhatsNewView(release: release) { WhatsNewEngine().markSeen(release) }
            case let .testFlight(message):
                TestFlightCommunicationView(message: message) {
                    TestFlightCommunicationEngine().markSeen(message)
                }
            case .assistSettings:
                AssistSettingsView()
            case let .downloadManager(viewModel):
                // The case is only ever set on iOS 17+ (the `WKDownload` delegate path); guard for the floor.
                if #available(iOS 17.0, *) {
                    DownloadManagerView(viewModel: viewModel)
                    #if !targetEnvironment(macCatalyst)
                        .presentationDetents([.medium, .large])
                    #endif
                }
            case let .serverSelect(prompt, includeSettings, onSelect):
                ServerSelectView(prompt: prompt, includeSettings: includeSettings, selectAction: onSelect)
                    .modify { view in
                        if #available(iOS 16.4, *) {
                            view
                                .presentationDetents([.medium, .large])
                                .presentationBackground(Color(uiColor: .systemBackground))
                        } else {
                            view
                        }
                    }
            }
        }
        .fullScreenCover(item: $viewModel.fullScreenCover, onDismiss: { refreshWebView() }) { cover in
            switch cover {
            case let .onboardingPermissions(server, steps):
                NavigationView {
                    OnboardingPermissionsNavigationView(
                        onboardingServer: server,
                        steps: steps,
                        onDismiss: { viewModel.fullScreenCover = nil }
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            CloseButton { viewModel.fullScreenCover = nil }
                        }
                    }
                }
                .navigationViewStyle(.stack)
                .injectingViewControllerProvider()
            }
        }
    }

    /// Re-evaluates the web view after a forced cover (onboarding permissions) is dismissed, mirroring the
    /// old `presentOverlayController`'s `onDisappear { refresh() }`.
    private func refreshWebView() {
        Current.sceneManager.webViewControllerPromise.done { $0.refresh() }
    }

    private var isShowingWebView: Bool {
        if case .webView = state.screen { return true }
        return false
    }
}
