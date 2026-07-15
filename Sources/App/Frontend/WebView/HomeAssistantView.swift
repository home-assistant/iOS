import Combine
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
    private enum Constants {
        static let minimumLoaderDuration: Duration = .seconds(1.8)
        static let loaderFadeOutDuration: Duration = .seconds(0.4)
    }

    let server: Server
    var onWebViewController: ((WebViewController) -> Void)?

    /// Published by the embedded `WebViewController`; drives the SwiftUI overlays below.
    @StateObject private var overlayState = WebFrontendOverlayState()

    /// Drives status-bar / home-indicator hiding from full-screen and kiosk settings (the status-bar
    /// *style* stays on `WebViewController`, as SwiftUI has no equivalent).
    @StateObject private var chrome = WebViewChromeState()

    @StateObject private var reconnectManager = WebViewReconnectManager()

    /// Changing this forces SwiftUI to discard the current `FrontendView` and create a fresh `WebViewController`.
    @State private var webViewResetID = UUID()
    @State private var webViewController: WebViewController?

    @State private var contentOpacity: Double = 0
    @State private var isFullScreenLoaderMounted = true
    @State private var isFullScreenLoaderVisible = true
    @State private var loaderMinimumDurationElapsed = false
    @State private var loaderCycleID = UUID()
    @State private var loaderMinimumDurationTask: Task<Void, Never>?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(server: Server, onWebViewController: @escaping (WebViewController) -> Void) {
        self.server = server
        self.onWebViewController = onWebViewController
    }

    /// Edges the web view ignores. When a themed status-bar bar is shown (edge-to-edge off), the web view's
    /// top is inset to sit below the bar; otherwise it runs fully edge-to-edge. Sides and bottom always bleed.
    private var webViewIgnoredSafeAreaEdges: Edge.Set {
        overlayState.statusBarColor == nil ? .all : [.horizontal, .bottom]
    }

    /// A theme-colored layer filling the top safe-area inset above the web view. Shown only when
    /// `overlayState` publishes a color (iOS, edge-to-edge off), in which case the web view's top is inset to
    /// sit below it. Drawn full-bleed behind the web view so only the otherwise-uncovered status-bar inset
    /// shows the color — the web view (opaque) covers everything below the top inset.
    @ViewBuilder
    private var themedStatusBar: some View {
        if let color = overlayState.statusBarColor {
            Color(uiColor: color)
                .ignoresSafeArea()
        }
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .topLeading) {
                FrontendView(
                    server: server,
                    onWebViewController: handleWebViewController,
                    resetFrontendAction: resetWebFrontend,
                    reconnectManager: reconnectManager,
                    overlayState: overlayState
                )
                .id(webViewResetID)
                .ignoresSafeArea(edges: webViewIgnoredSafeAreaEdges)
                macTitleBar
            }
            .opacity(contentOpacity)
            noActiveURLState
            standByView
        }
        .background(themedStatusBar)
        .animation(DesignSystem.Animation.easeInOutFaster, value: overlayState.emptyState != nil)
        .animation(DesignSystem.Animation.easeInOutFaster, value: overlayState.showsNoActiveURL)
        .statusBarHidden(chrome.statusBarHidden)
        .persistentSystemOverlays(chrome.homeIndicatorHidden ? .hidden : .automatic)
        .onAppear { fade(to: 1) }
        .onDisappear {
            loaderMinimumDurationTask?.cancel()
            fade(to: 0)
        }
        .onChange(of: overlayState.isLoading) { isLoading in
            if isLoading {
                beginFullScreenLoaderCycle()
            }
        }
        .onChange(of: overlayState.connectionState) { _ in
            updateFullScreenLoaderVisibility()
        }
        .onReceive(overlayState.$emptyState) { _ in
            updateFullScreenLoaderVisibility()
        }
    }

    private func fade(to opacity: Double) {
        guard !reduceMotion else {
            contentOpacity = opacity
            return
        }
        withAnimation(DesignSystem.Animation.easeInOutSlower) {
            contentOpacity = opacity
        }
    }

    @ViewBuilder
    private var macTitleBar: some View {
        if Current.isCatalyst {
            MacWebViewTitleBar(
                server: server,
                webViewController: webViewController
            )
            .frame(width: .zero, height: .zero)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var noActiveURLState: some View {
        if overlayState.showsNoActiveURL {
            ConnectionSecurityLevelBlockView(server: server)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var standByView: some View {
        if shouldShowStandByView, !overlayState.showsNoActiveURL {
            HomeAssistantStandByView(
                server: server,
                emptyState: displayedEmptyState,
                isLoading: overlayState.isLoading
            )
            .opacity(standByOpacity)
            .allowsHitTesting(standByOpacity > 0)
        }
    }

    private var shouldShowStandByView: Bool {
        isFullScreenLoaderMounted || overlayState.emptyState != nil
    }

    private var displayedEmptyState: WebFrontendOverlayState.EmptyStateContent? {
        guard let emptyState = overlayState.emptyState else { return nil }
        guard isFullScreenLoaderMounted else { return emptyState }
        return loaderMinimumDurationElapsed ? emptyState : nil
    }

    private var standByOpacity: Double {
        overlayState.emptyState == nil && !isFullScreenLoaderVisible ? 0 : 1
    }

    private func resetWebFrontend() {
        overlayState.emptyState = nil
        overlayState.showsNoActiveURL = false
        webViewController = nil
        beginFullScreenLoaderCycle()
        webViewResetID = UUID()
    }

    private func beginFullScreenLoaderCycle() {
        let cycleID = UUID()
        loaderMinimumDurationTask?.cancel()
        isFullScreenLoaderMounted = true
        withAnimation(DesignSystem.Animation.default) {
            isFullScreenLoaderVisible = true
        }
        loaderMinimumDurationElapsed = false
        overlayState.connectionState = .unknown
        loaderCycleID = cycleID
        loaderMinimumDurationTask = Task { @MainActor in
            try? await Task.sleep(for: Constants.minimumLoaderDuration)
            guard !Task.isCancelled, loaderCycleID == cycleID else { return }
            withAnimation(DesignSystem.Animation.default) {
                loaderMinimumDurationElapsed = true
            }
            updateFullScreenLoaderVisibility()
        }
    }

    private func updateFullScreenLoaderVisibility() {
        guard isFullScreenLoaderMounted, loaderMinimumDurationElapsed else { return }

        if overlayState.emptyState != nil {
            withAnimation(DesignSystem.Animation.default) {
                isFullScreenLoaderVisible = true
            }
            return
        }

        guard isFullScreenLoaderVisible, overlayState.connectionState == .connected else { return }

        let finishingCycleID = loaderCycleID
        withAnimation(DesignSystem.Animation.default) {
            isFullScreenLoaderVisible = false
        }

        Task { @MainActor in
            try? await Task.sleep(for: Constants.loaderFadeOutDuration)
            guard loaderCycleID == finishingCycleID, !isFullScreenLoaderVisible else { return }
            isFullScreenLoaderMounted = false
        }
    }


    private func handleWebViewController(_ controller: WebViewController) {
        Task { @MainActor in
            webViewController = controller
            onWebViewController?(controller)
        }
    }
}

/// Observes the settings that drive system-chrome hiding (full-screen, kiosk hide-status-bar) so
/// `HomeAssistantView` can hide the status bar / home indicator in SwiftUI rather than via UIKit overrides
/// on `WebViewController`.
@MainActor
final class WebViewChromeState: ObservableObject {
    @Published private(set) var statusBarHidden: Bool
    @Published private(set) var homeIndicatorHidden: Bool

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.statusBarHidden = Self.resolveStatusBarHidden()
        self.homeIndicatorHidden = Current.settingsStore.fullScreen

        Current.kiosk.settingsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: SettingsStore.webViewRelatedSettingDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    private func refresh() {
        statusBarHidden = Self.resolveStatusBarHidden()
        homeIndicatorHidden = Current.settingsStore.fullScreen
    }

    private static func resolveStatusBarHidden() -> Bool {
        Current.settingsStore.fullScreen
            || (Current.kioskSettings.enabled && Current.kioskSettings.hideStatusBar)
    }
}
