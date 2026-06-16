import Combine
import Shared
import UIKit

/// Observable state the `WebViewController` publishes to its SwiftUI host (`HomeAssistantView`) so blocking
/// screens can be layered over the web view in SwiftUI (a `ZStack`) instead of presented as UIKit
/// modals/subviews — letting app-level sheets (e.g. Settings) float over them without tearing them down.
@MainActor
final class WebFrontendOverlayState: ObservableObject {
    /// True when the active server has no usable URL; drives the no-active-URL overlay.
    @Published var showsNoActiveURL = false

    /// Non-nil while the disconnected/unauthenticated empty state should be shown.
    @Published var emptyState: EmptyStateContent?

    /// Theme color for the top status-bar inset, drawn by `HomeAssistantView` over the (always edge-to-edge)
    /// web view. Nil when there should be no themed bar — i.e. edge-to-edge / full-screen is enabled, or on
    /// Catalyst (where the native status-bar view handles it).
    @Published var statusBarColor: UIColor?

    /// Server context + actions for the macOS (Catalyst) title-bar buttons, rendered by `MacStatusBarButtonsView`
    /// as a SwiftUI overlay in `HomeAssistantView`. Nil on iOS (no window title bar) and until the Catalyst
    /// `WebViewController` publishes it.
    @Published var macStatusBar: MacStatusBarButtonsContent?

    /// Data + actions to render `WebViewEmptyStateView` as a SwiftUI overlay. Built by `WebViewController`,
    /// which owns the connection state and the actions (retry / settings / error details / re-auth).
    struct EmptyStateContent {
        let style: WebViewEmptyStateStyle
        let server: Server
        let showsErrorDetailsButton: Bool
        let availableReauthURLTypes: [ConnectionInfo.URLType]
        let retryAction: () -> Void
        let settingsAction: () -> Void
        let errorDetailsAction: () -> Void
        let reauthAction: (ConnectionInfo.URLType) -> Void
        let dismissAction: () -> Void
    }

    /// Data + actions to render `MacStatusBarButtonsView`. Built by `WebViewController`, which owns the web
    /// view the navigation / copy / paste / reload actions drive.
    struct MacStatusBarButtonsContent {
        let server: Server
        let servers: [Server]
        let refresh: () -> Void
        let openServer: (Server) -> Void
        let openInSafari: () -> Void
        let goBack: () -> Void
        let goForward: () -> Void
        let copy: () -> Void
        let paste: () -> Void
    }
}
