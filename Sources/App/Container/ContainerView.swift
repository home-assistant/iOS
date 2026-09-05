import PromiseKit
import Shared
import SwiftUI
import UIKit

struct ContainerView: View {
    @StateObject private var state = OnboardingStateObservable()
    @StateObject private var viewModel = ContainerViewModel()
    @State private var coordinator = AppContainerCoordinator()

    var body: some View {
        Group {
            switch state.screen {
            case let .onboarding(style):
                OnboardingNavigationView(onboardingStyle: style)
                    .id(style)
            case let .webView(server, initialPath):
                HomeAssistantView(server: server, initialPath: initialPath) { webViewController in
                    coordinator.setFrontend(webViewController)
                    Current.sceneManager.setWebViewController(webViewController)
                }
                .id(server.identifier.rawValue)
            case .recoveredServerImport:
                RecoveredServersImportView(onImport: { state.completeRecoveredServerImport() })
            case let .recoveredServerReauth(server):
                RecoveredServerReauthView(server: server, state: state)
            }
        }
        .navigationTitle(" ") // Remove default macOS title
        .onAppear {
            coordinator.onOpenServer = { state.showWebView(for: $0) }
            coordinator.onSetup = { state.reevaluate() }
            coordinator.onShowSettings = { [weak coordinator] pushOntoNavigationStack in
                // Push only in compact width, read from the window at presentation time.
                let sizeClass = coordinator?.window?.traitCollection.horizontalSizeClass
                if pushOntoNavigationStack, sizeClass == .compact {
                    AppSettingsPresenter.shared.isPushPresented = true
                } else {
                    AppSettingsPresenter.shared.presentSettings()
                }
            }
            coordinator.onShowAssistSettings = { viewModel.presentAssistSettings() }
            coordinator.onShowDownloadManager = { viewModel.presentDownloadManager($0) }
            coordinator.onShowOnboardingPermissions = { viewModel.presentOnboardingPermissions(server: $0, steps: $1) }
            Current.sceneManager.registerAppCoordinator(coordinator)
            fadeOutLaunchSplashIfNeeded(for: state.screen)
        }
        .onChange(of: state.screen) { screen in
            fadeOutLaunchSplashIfNeeded(for: screen)
        }
        // `fullScreenCover` is deliberately left alone: it carries the forced onboarding-permissions
        // decision, which a deep link must not be able to skip.
        .dismissesOnAppNavigation { viewModel.presentedSheet = nil }
        .sheet(item: $viewModel.presentedSheet) { sheet in
            switch sheet {
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

    /// The recovered-server screens have no Home Assistant logo for the launch splash to morph into, so
    /// fade the splash out as soon as one of them becomes the top-level screen.
    private func fadeOutLaunchSplashIfNeeded(for screen: OnboardingStateObservable.Screen) {
        switch screen {
        case .recoveredServerImport, .recoveredServerReauth:
            LaunchSplashOverlayState.shared.fadeOut()
        case .onboarding, .webView:
            break
        }
    }

    /// Re-evaluates the web view after a forced cover (onboarding permissions) is dismissed, mirroring the
    /// old `presentOverlayController`'s `onDisappear { refresh() }`.
    private func refreshWebView() {
        Current.sceneManager.webViewControllerPromise.done { $0.refresh() }
    }
}
