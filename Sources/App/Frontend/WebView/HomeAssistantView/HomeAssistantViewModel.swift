import Combine
import Shared
import SwiftUI
import UIKit

@MainActor
final class HomeAssistantViewModel: ObservableObject {
    private enum Constants {
        static let minimumLoaderDuration: Duration = {
            if Current.isCatalyst {
                .seconds(0.8)
            } else {
                .seconds(1.8)
            }
        }()

        static let loaderFadeOutDuration: Duration = .seconds(0.4)
        static let pullToRefreshThreshold: CGFloat = 148
        static let pullToRefreshFadeInDelay: Duration = .milliseconds(120)
        static let pullToRefreshFallbackFadeInDelay: Duration = .seconds(1)
    }

    let server: Server
    let overlayState: WebFrontendOverlayState
    let chrome: WebViewChromeState
    let reconnectManager: WebViewReconnectManager

    @Published var webViewResetID = UUID()
    @Published var webViewController: WebViewController?
    @Published var contentOpacity: Double = 0
    @Published var isFullScreenLoaderMounted = true
    @Published var isFullScreenLoaderVisible = true
    @Published var loaderMinimumDurationElapsed = false
    @Published var pullToRefreshProgress: CGFloat = 0
    @Published var isPullToRefreshActive = false

    private let onWebViewController: ((WebViewController) -> Void)?

    // Animation flow lives here rather than in `WebViewController`:
    // - Pull-to-refresh fades the hosted web content out, then starts the normal web view refresh path.
    // - `overlayState.isLoading` mounts the full-screen standby loader and fades the web content back in behind it.
    // - The standby loader remains mounted until both the minimum duration has elapsed and the frontend reconnects.
    // - Empty-state content waits for the same minimum duration so transient reload failures don't flash immediately.
    private var loaderCycleID = UUID()
    private var pullToRefreshFadeCycleID = UUID()
    private var loaderMinimumDurationTask: Task<Void, Never>?
    private var pullToRefreshFadeTask: Task<Void, Never>?
    private var isWaitingToFadeInAfterPullToRefresh = false
    private var reduceMotion = false
    private var pullToRefreshObserver: HomeAssistantPullToRefreshObserver?
    private var cancellables = Set<AnyCancellable>()

    init(
        server: Server,
        overlayState: WebFrontendOverlayState? = nil,
        chrome: WebViewChromeState? = nil,
        reconnectManager: WebViewReconnectManager? = nil,
        onWebViewController: ((WebViewController) -> Void)? = nil
    ) {
        self.server = server
        self.overlayState = overlayState ?? WebFrontendOverlayState()
        self.chrome = chrome ?? WebViewChromeState()
        self.reconnectManager = reconnectManager ?? WebViewReconnectManager()
        self.onWebViewController = onWebViewController

        bindObservableChildren()
        bindOverlayState()
    }

    deinit {
        loaderMinimumDurationTask?.cancel()
        pullToRefreshFadeTask?.cancel()
    }

    var webViewIgnoredSafeAreaEdges: Edge.Set {
        overlayState.statusBarColor == nil ? .all : [.horizontal, .bottom]
    }

    var shouldShowStandByView: Bool {
        isFullScreenLoaderMounted || overlayState.emptyState != nil
    }

    var showsPullToRefresh: Bool {
        pullToRefreshProgress > 0 || isPullToRefreshActive
    }

    var displayedEmptyState: WebFrontendOverlayState.EmptyStateContent? {
        guard let emptyState = overlayState.emptyState else { return nil }
        guard isFullScreenLoaderMounted else { return emptyState }
        return loaderMinimumDurationElapsed ? emptyState : nil
    }

    var standByOpacity: Double {
        overlayState.emptyState == nil && !isFullScreenLoaderVisible ? 0 : 1
    }

    func updateReduceMotion(_ reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
    }

    func fade(to opacity: Double, reduceMotion: Bool) {
        updateReduceMotion(reduceMotion)
        guard !reduceMotion else {
            contentOpacity = opacity
            return
        }
        withAnimation(DesignSystem.Animation.easeInOutSlower) {
            contentOpacity = opacity
        }
    }

    func disappear(reduceMotion: Bool) {
        loaderMinimumDurationTask?.cancel()
        pullToRefreshFadeTask?.cancel()
        isWaitingToFadeInAfterPullToRefresh = false
        fade(to: 0, reduceMotion: reduceMotion)
    }

    func resetWebFrontend() {
        overlayState.emptyState = nil
        overlayState.showsNoActiveURL = false
        webViewController = nil
        beginFullScreenLoaderCycle()
        webViewResetID = UUID()
    }

    func handleWebViewController(_ controller: WebViewController) {
        webViewController = controller
        onWebViewController?(controller)
    }

    func handleWebViewLoaded(_ controller: WebViewController) {
        guard !Current.isCatalyst else { return }
        pullToRefreshObserver = HomeAssistantPullToRefreshObserver(
            webView: controller.webView,
            threshold: Constants.pullToRefreshThreshold,
            onStateChange: { [weak self] progress, isRefreshing in
                self?.pullToRefreshProgress = progress
                self?.isPullToRefreshActive = isRefreshing
            },
            onRefresh: { [weak self, weak controller] in
                self?.performPullToRefresh(using: controller)
            }
        )
    }

    private func performPullToRefresh(using controller: WebViewController?) {
        // Keep the web-view reload semantics centralized in `WebViewController`; this view model only owns the
        // native transition that hides the current page until the full-screen loader is ready.
        beginPullToRefreshFadeOut()
        Current.Log.info("Pull-to-refresh: resetting frontend cache before reload")
        Current.websiteDataStoreHandler
            .cleanCache(dataTypes: WebsiteDataStoreHandlerImpl.frontendAssetDataTypes) {
                controller?.pullToRefreshActions()
            }
    }

    private func beginPullToRefreshFadeOut() {
        guard !reduceMotion else { return }

        let cycleID = UUID()
        pullToRefreshFadeCycleID = cycleID
        isWaitingToFadeInAfterPullToRefresh = true
        pullToRefreshFadeTask?.cancel()

        withAnimation(DesignSystem.Animation.easeInOutFaster) {
            contentOpacity = 0
        }

        pullToRefreshFadeTask = Task { @MainActor in
            try? await Task.sleep(for: Constants.pullToRefreshFallbackFadeInDelay)
            guard !Task.isCancelled, pullToRefreshFadeCycleID == cycleID else { return }
            fadeInAfterPullToRefresh(cycleID: cycleID, delay: .zero)
        }
    }

    private func fadeInAfterPullToRefreshIfNeeded() {
        guard isWaitingToFadeInAfterPullToRefresh, !reduceMotion else { return }
        fadeInAfterPullToRefresh(cycleID: pullToRefreshFadeCycleID, delay: Constants.pullToRefreshFadeInDelay)
    }

    private func fadeInAfterPullToRefresh(cycleID: UUID, delay: Duration) {
        pullToRefreshFadeTask?.cancel()
        pullToRefreshFadeTask = Task { @MainActor in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled, pullToRefreshFadeCycleID == cycleID else { return }
            isWaitingToFadeInAfterPullToRefresh = false
            withAnimation(DesignSystem.Animation.easeInOutFaster) {
                contentOpacity = 1
            }
        }
    }

    private func bindObservableChildren() {
        overlayState.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        chrome.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    private func bindOverlayState() {
        overlayState.$isLoading
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.beginFullScreenLoaderCycle()
                    self?.fadeInAfterPullToRefreshIfNeeded()
                } else {
                    self?.pullToRefreshObserver?.finishRefreshing()
                }
            }
            .store(in: &cancellables)

        overlayState.$connectionState
            .sink { [weak self] _ in self?.updateFullScreenLoaderVisibility() }
            .store(in: &cancellables)

        overlayState.$emptyState
            .sink { [weak self] _ in self?.updateFullScreenLoaderVisibility() }
            .store(in: &cancellables)
    }

    private func beginFullScreenLoaderCycle() {
        // A load cycle starts optimistic: show the standby loader, hold empty-state content back, and wait for
        // the frontend connection state to confirm whether we can fade the loader away or should show an error.
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
}
