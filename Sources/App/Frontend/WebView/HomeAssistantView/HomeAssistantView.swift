import Shared
import SwiftUI
import UIKit

struct HomeAssistantView: View, WebFrontendView {
    private enum Constants {
        static let launchMessagesFallbackDelay: TimeInterval = 2
    }

    @StateObject private var viewModel: HomeAssistantViewModel
    /// What's-New / TestFlight sheets are owned here so they can only ever present over the web
    /// frontend, never over onboarding.
    @StateObject private var launchMessages = LaunchMessagesState()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showServerSelection = false
    @Namespace private var serverSelectionNamespace

    init(server: Server, onWebViewController: @escaping (WebViewController) -> Void) {
        self.init(server: server, initialPath: nil, onWebViewController: onWebViewController)
    }

    init(server: Server, initialPath: String?, onWebViewController: @escaping (WebViewController) -> Void) {
        _viewModel = StateObject(
            wrappedValue: HomeAssistantViewModel(
                server: server,
                initialPath: initialPath,
                onWebViewController: onWebViewController
            )
        )
    }

    /// The themed status-bar strip keeps the last frontend-provided colour until WebKit sends a new update.
    private var themedStatusBar: some View {
        GeometryReader { proxy in
            if let color = viewModel.overlayState.statusBarColor {
                Color(uiColor: color)
                    .frame(height: proxy.safeAreaInsets.top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
            }
        }
        .allowsHitTesting(false)
    }

    var body: some View {
        ZStack {
            // The frontend content group is separate from the standby overlay so it can fade with pull-to-refresh and
            // reloads.
            ZStack(alignment: .topLeading) {
                themedStatusBar
                    .opacity(viewModel.webViewContentOpacity)
                homeAssistant
                    .opacity(viewModel.webViewContentOpacity)
                pullToRefreshIndicator
                macTitleBar
                    .opacity(viewModel.webViewContentOpacity)
            }
            noActiveURLState
            standByView
        }
        .sheet(isPresented: $showServerSelection) {
            ServerSelectView(prompt: nil, includeSettings: false, selectAction: viewModel.selectServer)
                .presentationDetents([.medium, .large])
                .presentationBackground(Color(uiColor: .systemBackground))
                .modify { view in
                    if #available(iOS 18.0, *) {
                        view.navigationTransition(.zoom(
                            sourceID: HomeAssistantStandByView.serverSelectionTransitionID,
                            in: serverSelectionNamespace
                        ))
                    } else {
                        view
                    }
                }
        }
        .animation(DesignSystem.Animation.easeInOutFaster, value: viewModel.overlayState.emptyState != nil)
        .animation(DesignSystem.Animation.easeInOutFaster, value: viewModel.overlayState.showsNoActiveURL)
        .statusBarHidden(viewModel.chrome.statusBarHidden)
        .persistentSystemOverlays(viewModel.chrome.homeIndicatorHidden ? .hidden : .automatic)
        .onAppear {
            viewModel.fade(to: 1, reduceMotion: reduceMotion)
            // Fallback for frontends that never finish loading (e.g. connection errors): still show
            // the launch messages, but well after any screen-swap transition (post-onboarding) has
            // finished — presenting a sheet mid-swap corrupts the presenting hierarchy and leaves a
            // blank screen behind on dismissal.
            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.launchMessagesFallbackDelay) {
                launchMessages.evaluateIfNeeded()
            }
        }
        .onChange(of: viewModel.shouldShowStandByView) { showsStandBy in
            // The frontend is loaded and on screen — the settled moment to present launch messages.
            if !showsStandBy {
                launchMessages.evaluateIfNeeded()
            }
        }
        .onChange(of: reduceMotion) { reduceMotion in
            viewModel.updateReduceMotion(reduceMotion)
        }
        .onDisappear { viewModel.disappear(reduceMotion: reduceMotion) }
        .sheet(item: $launchMessages.presented, onDismiss: { launchMessages.showNext() }) { message in
            switch message {
            case let .whatsNew(release):
                WhatsNewView(release: release) { WhatsNewEngine().markSeen(release) }
            case let .testFlight(message):
                TestFlightCommunicationView(message: message) {
                    TestFlightCommunicationEngine().markSeen(message)
                }
            }
        }
    }

    private var homeAssistant: some View {
        FrontendView(
            server: viewModel.server,
            initialPath: viewModel.initialPath,
            onWebViewController: viewModel.handleWebViewController,
            onWebViewLoaded: viewModel.handleWebViewLoaded,
            resetFrontendAction: viewModel.resetWebFrontend,
            reconnectManager: viewModel.reconnectManager,
            overlayState: viewModel.overlayState
        )
        .id(viewModel.webViewResetID)
        .ignoresSafeArea(edges: viewModel.webViewIgnoredSafeAreaEdges)
    }

    @ViewBuilder
    private var pullToRefreshIndicator: some View {
        if viewModel.showsPullToRefresh {
            HomeAssistantPullToRefreshView(
                progress: viewModel.pullToRefreshProgress,
                isRefreshing: viewModel.isPullToRefreshActive
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, DesignSystem.Spaces.two)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    // MARK: - macOS

    @ViewBuilder
    private var macTitleBar: some View {
        if Current.isCatalyst {
            MacWebViewTitleBar(
                server: viewModel.server,
                webViewController: viewModel.webViewController
            )
            .frame(width: .zero, height: .zero)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Empty states

    @ViewBuilder
    private var noActiveURLState: some View {
        if viewModel.overlayState.showsNoActiveURL {
            ConnectionSecurityLevelBlockView(server: viewModel.server)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var standByView: some View {
        if viewModel.shouldShowStandByView, !viewModel.overlayState.showsNoActiveURL {
            HomeAssistantStandByView(
                server: viewModel.server,
                emptyState: viewModel.displayedEmptyState,
                isLoading: viewModel.overlayState.isLoading,
                serverSelectionNamespace: serverSelectionNamespace,
                onSelectServerTapped: { showServerSelection = true },
                onGestureAction: { action in
                    viewModel.webViewController?.webViewGestureHandler.handleGestureAction(action)
                },
                onLogoDismiss: viewModel.forceDismissStandByView
            )
            .transition(.opacity)
            .opacity(viewModel.standByOpacity)
            .allowsHitTesting(viewModel.standByOpacity > 0)
        }
    }
}
