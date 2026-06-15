import PromiseKit
import Shared
import SwiftUI
import UIKit

/// The top-level content of the app's main window.
///
/// Decides — based on onboarding state — whether to render the onboarding flow or the Home Assistant web
/// frontend, and swaps between them as that state changes. This is the SwiftUI replacement for the
/// root-view-controller swapping that `WebViewWindowController` performed.
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
            case .recoveredServerImport:
                RecoveredServersImportView(onImport: { state.completeRecoveredServerImport() })
            case let .recoveredServerReauth(server):
                RecoveredServerReauthHostingView(server: server, state: state)
            }
        }
        .onAppear {
            coordinator.onOpenServer = { state.showWebView(for: $0) }
            coordinator.onSetup = { state.reevaluate() }
            coordinator.onShowSettings = { viewModel.presentSettings() }
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
            case .settings:
                SettingsView().injectingViewControllerProvider()
                    .onDisappear { refreshWebViewIfDisconnected() }
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
                    OnboardingPermissionsNavigationView(onboardingServer: server, steps: steps)
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
        #if targetEnvironment(macCatalyst)
        // Hide the macOS window title so it doesn't overlap the WebView's custom status-bar buttons.
        .background(TitlebarConfigurator())
        #endif
    }

    /// Re-evaluates the web view after a forced cover (onboarding permissions) is dismissed, mirroring the
    /// old `presentOverlayController`'s `onDisappear { refresh() }`.
    private func refreshWebView() {
        Current.sceneManager.webViewControllerPromise.done { $0.refresh() }
    }

    /// Re-evaluates the web view after Settings closes, but only when it isn't connected — so closing Settings
    /// on a healthy page doesn't reload it, while the no-active-URL / connection block still re-evaluates.
    private func refreshWebViewIfDisconnected() {
        Current.sceneManager.webViewControllerPromise.done { $0.refreshIfDisconnected() }
    }

    private var isShowingWebView: Bool {
        if case .webView = state.screen { return true }
        return false
    }
}
