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
    }

    let server: Server
    let initialPath: String?
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

    // The standby loader remains mounted until both the minimum duration has elapsed and the frontend reconnects.
    // Empty-state content waits for the same minimum duration so transient reload failures don't flash immediately.
    private var loaderCycleID = UUID()
    private var loaderMinimumDurationTask: Task<Void, Never>?

    // The frontend fires `frontend/loaded` exactly once per page load (it swaps out its `update` method after
    // firing), so reconnects within a living page only report `connected`. Once we've seen `loaded`, `connected`
    // is enough to dismiss the loader. A recreated view model implies a fresh page load, which fires it again.
    private var frontendLoadedOnce = false
    private var reduceMotion = false
    private var pullToRefreshObserver: HomeAssistantPullToRefreshObserver?
    private var cancellables = Set<AnyCancellable>()

    init(
        server: Server,
        initialPath: String? = nil,
        overlayState: WebFrontendOverlayState? = nil,
        chrome: WebViewChromeState? = nil,
        reconnectManager: WebViewReconnectManager? = nil,
        onWebViewController: ((WebViewController) -> Void)? = nil
    ) {
        self.server = server
        self.initialPath = initialPath
        self.overlayState = overlayState ?? WebFrontendOverlayState()
        self.chrome = chrome ?? WebViewChromeState()
        self.reconnectManager = reconnectManager ?? WebViewReconnectManager()
        self.onWebViewController = onWebViewController

        bindObservableChildren()
        bindOverlayState()
        beginFullScreenLoaderCycle()
    }

    deinit {
        loaderMinimumDurationTask?.cancel()
    }

    var webViewIgnoredSafeAreaEdges: Edge.Set {
        overlayState.statusBarColor == nil ? .all : [.horizontal, .bottom]
    }

    var shouldShowStandByView: Bool {
        isFullScreenLoaderMounted || overlayState.emptyState != nil
    }

    var webViewContentOpacity: Double {
        if overlayState.emptyState != nil || isFullScreenLoaderVisible || isPullToRefreshActive {
            return 0
        }

        guard pullToRefreshProgress > 0 else { return contentOpacity }
        return contentOpacity * Double(1 - min(1, max(0, pullToRefreshProgress)))
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

    /// On servers that support `frontend/loaded`, the first bootstrap must wait for that event (the frontend's
    /// own launcher screen is still up on plain `connected`).
    private func didReachLoaderReadyState(_ connectionState: FrontEndConnectionState) -> Bool {
        guard server.info.version >= .frontendLoadedExternalBus else {
            return connectionState.isReadyForDisplay
        }
        return connectionState.isReadyForDisplay && frontendLoadedOnce
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
        fade(to: 0, reduceMotion: reduceMotion)
    }

    func resetWebFrontend() {
        overlayState.emptyState = nil
        overlayState.showsNoActiveURL = false
        webViewController = nil
        beginFullScreenLoaderCycle()
        webViewResetID = UUID()
    }

    func cleanCacheAndReload() {
        Current.Log.info("Standby loader stuck; cleaning frontend cache and reloading")
        Current.websiteDataStoreHandler
            .cleanCache(dataTypes: WebsiteDataStoreHandlerImpl.frontendAssetDataTypes) { [weak self] in
                self?.resetWebFrontend()
            }
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
        Current.Log.info("Pull-to-refresh: resetting frontend cache before reload")
        Current.websiteDataStoreHandler
            .cleanCache(dataTypes: WebsiteDataStoreHandlerImpl.frontendAssetDataTypes) {
                controller?.pullToRefreshActions()
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
                    // A provisional navigation (initial load, pull-to-refresh, app-side refresh) loads the
                    // document from scratch, so a fresh frontend instance will fire `frontend/loaded` again.
                    self?.frontendLoadedOnce = false
                    self?.beginFullScreenLoaderCycle()
                } else {
                    self?.pullToRefreshObserver?.finishRefreshing()
                }
            }
            .store(in: &cancellables)

        overlayState.$connectionState
            .sink { [weak self] connectionState in
                self?.handleConnectionStateChange(connectionState)
            }
            .store(in: &cancellables)

        overlayState.$emptyState
            .sink { [weak self] emptyState in
                self?.updateFullScreenLoaderVisibility(hasEmptyState: emptyState != nil)
            }
            .store(in: &cancellables)
    }

    private func handleConnectionStateChange(_ connectionState: FrontEndConnectionState) {
        if connectionState == .loaded {
            frontendLoadedOnce = true
        }
        updateFullScreenLoaderVisibility(connectionState: connectionState)
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

    private func updateFullScreenLoaderVisibility(
        connectionState: FrontEndConnectionState? = nil,
        hasEmptyState: Bool? = nil
    ) {
        guard isFullScreenLoaderMounted, loaderMinimumDurationElapsed else { return }

        if hasEmptyState ?? (overlayState.emptyState != nil) {
            withAnimation(DesignSystem.Animation.default) {
                isFullScreenLoaderVisible = true
            }
            return
        }

        guard isFullScreenLoaderVisible,
              didReachLoaderReadyState(connectionState ?? overlayState.connectionState) else { return }

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

    /// Debug escape hatch: repeated taps on the standby logo dismiss the loader without waiting for the
    /// frontend connection state, so the frontend behind it can be inspected (e.g. when a `frontend/loaded`
    /// that never arrives keeps the loader up).
    func forceDismissStandByView() {
        Current.Log.info("Standby loader dismissed manually via logo taps")
        loaderMinimumDurationTask?.cancel()
        loaderMinimumDurationElapsed = true
        withAnimation(DesignSystem.Animation.default) {
            isFullScreenLoaderVisible = false
        }
        isFullScreenLoaderMounted = false
    }

    func selectServer(_ server: Server) {
        Current.sceneManager.appCoordinator.done { coordinator in
            coordinator.open(server: server)
        }
    }
}
