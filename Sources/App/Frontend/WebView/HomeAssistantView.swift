import Shared
import SwiftUI
import UIKit

struct HomeAssistantView: View, WebFrontendView {
    @StateObject private var viewModel: HomeAssistantViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(server: Server, onWebViewController: @escaping (WebViewController) -> Void) {
        _viewModel = StateObject(
            wrappedValue: HomeAssistantViewModel(
                server: server,
                onWebViewController: onWebViewController
            )
        )
    }

    @ViewBuilder
    private var themedStatusBar: some View {
        if let color = viewModel.overlayState.statusBarColor {
            Color(uiColor: color)
                .ignoresSafeArea()
        }
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .topLeading) {
                homeAssistant
                macTitleBar
            }
            .opacity(viewModel.contentOpacity)
            noActiveURLState
            standByView
        }
        .background(themedStatusBar)
        .animation(DesignSystem.Animation.easeInOutFaster, value: viewModel.overlayState.emptyState != nil)
        .animation(DesignSystem.Animation.easeInOutFaster, value: viewModel.overlayState.showsNoActiveURL)
        .statusBarHidden(viewModel.chrome.statusBarHidden)
        .persistentSystemOverlays(viewModel.chrome.homeIndicatorHidden ? .hidden : .automatic)
        .onAppear { viewModel.fade(to: 1, reduceMotion: reduceMotion) }
        .onDisappear { viewModel.disappear(reduceMotion: reduceMotion) }
    }

    private var homeAssistant: some View {
        FrontendView(
            server: viewModel.server,
            onWebViewController: viewModel.handleWebViewController,
            resetFrontendAction: viewModel.resetWebFrontend,
            reconnectManager: viewModel.reconnectManager,
            overlayState: viewModel.overlayState
        )
        .id(viewModel.webViewResetID)
        .ignoresSafeArea(edges: viewModel.webViewIgnoredSafeAreaEdges)
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
                isLoading: viewModel.overlayState.isLoading
            )
            .transition(.opacity)
            .opacity(viewModel.standByOpacity)
            .allowsHitTesting(viewModel.standByOpacity > 0)
        }
    }
}
