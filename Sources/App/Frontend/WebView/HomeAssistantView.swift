import Shared
import SwiftUI
import UIKit

/// The Home Assistant web frontend as a SwiftUI view: the web view (`FrontendView`) plus SwiftUI overlay
/// content layered on top in a `ZStack`. Blocking screens (the disconnected/unauthenticated empty state and
/// the no-active-URL screen) live here as state-driven overlays rather than UIKit modals/subviews on the
/// `WebViewController`, so app-level sheets (Settings) can float over them without tearing them down.
///
/// Rendered by `ContainerView` when onboarding is complete; conforms to `WebFrontendView`.
struct HomeAssistantView: View, WebFrontendView {
    let server: Server
    var onWebViewController: ((WebViewController) -> Void)?

    /// Published by the embedded `WebViewController`; drives the SwiftUI overlays below.
    @StateObject private var overlayState = WebFrontendOverlayState()

    init(server: Server, onWebViewController: @escaping (WebViewController) -> Void) {
        self.server = server
        self.onWebViewController = onWebViewController
    }

    /// Edges the web view ignores. When a themed status-bar bar is shown (edge-to-edge off), the web view's
    /// top is inset to sit below the bar; otherwise it runs fully edge-to-edge. Sides and bottom always bleed.
    private var webViewIgnoredSafeAreaEdges: Edge.Set {
        overlayState.statusBarColor == nil ? .all : [.horizontal, .bottom]
    }

    /// A theme-colored bar filling the top safe-area inset above the web view. Shown only when `overlayState`
    /// publishes a color (iOS, edge-to-edge off), in which case the web view's top is inset to sit below it.
    @ViewBuilder
    private var themedStatusBar: some View {
        if let color = overlayState.statusBarColor {
            Color(uiColor: color)
                .frame(maxWidth: .infinity)
                .frame(height: 0)
                .ignoresSafeArea(edges: .top)
        }
    }

    var body: some View {
        ZStack {
            FrontendView(server: server, onWebViewController: onWebViewController, overlayState: overlayState)
                .ignoresSafeArea(edges: webViewIgnoredSafeAreaEdges)

            if overlayState.showsNoActiveURL {
                ConnectionSecurityLevelBlockView(server: server)
                    .transition(.opacity)
            } else if let emptyState = overlayState.emptyState {
                WebViewEmptyStateView(
                    style: emptyState.style,
                    server: emptyState.server,
                    showsErrorDetailsButton: emptyState.showsErrorDetailsButton,
                    availableReauthURLTypes: emptyState.availableReauthURLTypes,
                    retryAction: emptyState.retryAction,
                    settingsAction: emptyState.settingsAction,
                    errorDetailsAction: emptyState.errorDetailsAction,
                    reauthAction: emptyState.reauthAction,
                    dismissAction: emptyState.dismissAction
                )
                .transition(.opacity)
            }
        }
        .overlay(alignment: .top) { themedStatusBar }
        .animation(DesignSystem.Animation.easeInOutFaster, value: overlayState.emptyState != nil)
        .animation(DesignSystem.Animation.easeInOutFaster, value: overlayState.showsNoActiveURL)
    }
}
