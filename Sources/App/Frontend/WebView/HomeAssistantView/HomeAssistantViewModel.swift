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
                .seconds(1.2)
            }
        }()

        static let loaderFadeOutDuration: Duration = .seconds(0.4)
        /// How long the loader may stay up once the navigation itself has finished before the app stops
        /// waiting for a frontend connection state that may never arrive. Comfortably longer than the
        /// empty-state grace period (`SettingsStore.webViewEmptyStateTimeout`, five seconds by default), so a
        /// genuine disconnection still gets to surface as the empty state rather than as a bare web view.
        static let loaderWatchdogTimeout: Duration = .seconds(10)
        /// Upper bound for the pull distance; the observer shortens it on viewports too short to reach it
        /// in a single swipe, such as iPhone landscape.
        static let pullToRefreshMaximumThreshold: CGFloat = 148
    }

    let server: Server
    let initialPath: String?
    let overlayState: WebFrontendOverlayState
    let chrome: WebViewChromeState
    let reconnectManager: WebViewReconnectManager
    /// Feeds the App Labs native macOS sidebar; only started once that sidebar is on screen.
    let macSidebar: MacSidebarViewModel

    @Published var webViewResetID = UUID()
    @Published var webViewController: WebViewController?
    @Published var contentOpacity: Double = 0
    @Published var isFullScreenLoaderMounted = true
    @Published var isFullScreenLoaderVisible = true
    @Published var loaderMinimumDurationElapsed = false
    @Published var pullToRefreshProgress: CGFloat = 0
    @Published var isPullToRefreshActive = false

    private let onWebViewController: ((WebViewController) -> Void)?

    /// Overridable so tests can exercise the watchdog without waiting out the real timeout.
    var loaderWatchdogTimeout = Constants.loaderWatchdogTimeout

    // The standby loader remains mounted until both the minimum duration has elapsed and the frontend reconnects.
    // Empty-state content waits for the same minimum duration so transient reload failures don't flash immediately.
    private var loaderCycleID = UUID()
    private var loaderMinimumDurationTask: Task<Void, Never>?
    private var loaderWatchdogTask: Task<Void, Never>?

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
        self.macSidebar = MacSidebarViewModel(server: server, overlayState: self.overlayState)

        macSidebar.onNavigate = { [weak self] path in
            self?.webViewController?.openSidebarPath(path)
        }
        macSidebar.onShowNotifications = { [weak self] in
            self?.webViewController?.webViewExternalMessageHandler.sendExternalBusCommandWithRetry(
                command: .showNotifications,
                payload: nil
            )
        }
        macSidebar.readLocalStorage = { [weak self] key, completion in
            guard let webViewController = self?.webViewController else {
                completion(nil)
                return
            }
            webViewController.evaluateJavaScript("window.localStorage.getItem('\(key)')") { result, _ in
                completion(result as? String)
            }
        }

        bindObservableChildren()
        bindOverlayState()
        beginFullScreenLoaderCycle()
    }

    deinit {
        loaderMinimumDurationTask?.cancel()
        loaderWatchdogTask?.cancel()
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
        loaderWatchdogTask?.cancel()
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
            maximumThreshold: Constants.pullToRefreshMaximumThreshold,
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
                    self?.armLoaderWatchdog()
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
        loaderWatchdogTask?.cancel()
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

    /// The loader only ever comes down on a frontend connection state, and that report can go missing: the
    /// frontend announces `frontend/loaded` exactly once per page load, external-bus messages that arrive
    /// while the app is backgrounded are dropped, and a document restored from WebKit's page cache never
    /// announces itself again (`handleFrontendRestoredFromPageCache` covers that, but only while the frontend
    /// was connected when the page was cached). The frontend behind the loader is alive in those cases, so
    /// once the navigation itself has finished, wait a bounded amount of time for a connection state and then
    /// get out of the user's way rather than covering a working frontend indefinitely.
    private func armLoaderWatchdog() {
        guard isFullScreenLoaderMounted else { return }
        let cycleID = loaderCycleID
        loaderWatchdogTask?.cancel()
        loaderWatchdogTask = Task { @MainActor in
            try? await Task.sleep(for: loaderWatchdogTimeout)
            guard !Task.isCancelled, loaderCycleID == cycleID, isFullScreenLoaderMounted,
                  !overlayState.isLoading, overlayState.emptyState == nil else { return }
            Current.Log.error("Standby loader stuck with no frontend report after loading, dismissing it")
            dismissStandByView()
        }
    }

    /// Debug escape hatch: repeated taps on the standby logo dismiss the loader without waiting for the
    /// frontend connection state, so the frontend behind it can be inspected (e.g. when a `frontend/loaded`
    /// that never arrives keeps the loader up).
    func forceDismissStandByView() {
        Current.Log.info("Standby loader dismissed manually via logo taps")
        dismissStandByView()
    }

    private func dismissStandByView() {
        loaderMinimumDurationTask?.cancel()
        loaderWatchdogTask?.cancel()
        loaderMinimumDurationElapsed = true
        withAnimation(DesignSystem.Animation.default) {
            isFullScreenLoaderVisible = false
        }
        isFullScreenLoaderMounted = false
    }

    /// Opens the Settings sheet on its compact server picker, activating whatever the user picks. Zooms out of
    /// the stand-by view's server pill, which is the only thing that triggers it.
    func presentServerSelection() {
        Current.sceneManager.appCoordinator.done { coordinator in
            coordinator.selectServer(prompt: nil, zoomsFromStandBy: true) { server in
                coordinator.activate(server: server)
            }
        }
    }
}
