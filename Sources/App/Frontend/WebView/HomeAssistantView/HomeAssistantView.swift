import Shared
import SwiftUI
import UIKit

struct HomeAssistantView: View, WebFrontendView {
    @StateObject private var viewModel: HomeAssistantViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(server: Server, initialPath: String? = nil, onWebViewController: @escaping (WebViewController) -> Void) {
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
        .animation(DesignSystem.Animation.easeInOutFaster, value: viewModel.overlayState.emptyState != nil)
        .animation(DesignSystem.Animation.easeInOutFaster, value: viewModel.overlayState.showsNoActiveURL)
        .statusBarHidden(viewModel.chrome.statusBarHidden)
        .persistentSystemOverlays(viewModel.chrome.homeIndicatorHidden ? .hidden : .automatic)
        .onAppear { viewModel.fade(to: 1, reduceMotion: reduceMotion) }
        .onChange(of: reduceMotion) { reduceMotion in
            viewModel.updateReduceMotion(reduceMotion)
        }
        .onDisappear { viewModel.disappear(reduceMotion: reduceMotion) }
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
