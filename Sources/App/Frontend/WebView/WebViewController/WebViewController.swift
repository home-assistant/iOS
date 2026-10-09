import AVFoundation
import AVKit
import Combine
import CoreLocation
import HAKit
import Improv_iOS
import KeychainAccess
import PromiseKit
import Shared
import SwiftUI
@preconcurrency import WebKit

/// Hosts the Home Assistant frontend in a `WKWebView`. One class for both platforms: a `UIViewController` on
/// iOS and an `NSViewController` on the Mac, with the chrome each platform draws around the web view kept
/// behind `#if`.
final class WebViewController: PlatformViewController, WKNavigationDelegate, WKUIDelegate {
    var webView: WKWebView!
    let server: Server

    var urlObserver: NSKeyValueObservation?
    var windowTitleObserver: NSKeyValueObservation?
    /// Watches `.siriEntityExposureDidChange` so what is published on `userActivity` follows the
    /// user's Siri exposure setting; see `WebViewController+OnscreenContent`.
    var siriExposureObserver: NSObjectProtocol?
    /// The entity the frontend's more-info dialog is showing, reported over the external bus. Mirrored
    /// onto `overlayState` so the App Labs tab bar can hide while the dialog is up.
    var onscreenEntityId: String? {
        didSet {
            overlayState?.isMoreInfoDialogOpen = onscreenEntityId != nil
        }
    }

    /// The path the dialog opened over, so a route change is recognised as having closed it.
    var onscreenEntityPath: String?
    /// The in-flight publish of what is on screen, cancelled when a newer one replaces it.
    var onscreenContentTask: Task<Void, Never>?
    var emptyStateTitleObserver: AnyCancellable?
    var tokens = [HACancellable]()

    #if os(iOS)
    let leftEdgePanGestureRecognizer: UIScreenEdgePanGestureRecognizer
    let rightEdgeGestureRecognizer: UIScreenEdgePanGestureRecognizer
    #endif

    var statusBarView: PlatformView?
    /// Stands in for the frontend's Assist button as the zoom transition's source; see `AssistZoomAnchorView`.
    var assistZoomAnchorView: PlatformView?
    var pendingAssistZoomSourceView: PlatformView?
    var presentsNextAssistAsSheet = false
    /// An overlay presented from the window while this view was off screen behind the App Labs tab bar.
    weak var detachedOverlayController: PlatformViewController?
    #if os(iOS)
    var tabBarAssistZoomAnchor: AssistZoomAnchorView?
    #endif
    var webViewTopConstraint: NSLayoutConstraint?
    /// Pins the bottom of `statusBarView`; on iOS it follows the web view's top edge.
    var statusBarBottomConstraint: NSLayoutConstraint?
    var bannerPresenter: any BannerPresenter = DefaultBannerPresenter()
    var latestLoadError: Error?

    var initialURL: URL?
    var initialURLPath: String?
    #if os(iOS)
    var statusBarButtonsStack: UIStackView?
    #endif
    var lastNavigationWasServerError = false
    var didHandleServerErrorResponse = false
    var reconnectBackgroundTimer: Timer? {
        willSet {
            if reconnectBackgroundTimer != newValue {
                reconnectBackgroundTimer?.invalidate()
            }
        }
    }

    var connectionState: FrontEndConnectionState = .unknown

    /// Set when the user signed out from the frontend. The server stays registered, so the empty state
    /// asks for a log in rather than reporting an expired session, until re-authentication succeeds.
    var didLogOut = false

    /// Set when a load failed because of the client certificate (mTLS): the server asked for one the
    /// device does not have, or refused the one it has. No retry fixes that, so the empty state asks for a
    /// certificate import instead. Cleared once the frontend loads or the empty state goes away.
    var clientCertificateIssue: ClientCertificateIssue?

    /// Whether the navigation in flight received a client certificate challenge from the server. A TLS
    /// failure after one is a certificate problem, not a connectivity one; reset when a navigation starts.
    var didReceiveClientCertificateChallenge = false

    /// Set by `FrontendView`; lets connection/URL state drive SwiftUI overlays in `HomeAssistantView`
    /// instead of UIKit modals presented from here.
    var overlayState: WebFrontendOverlayState? {
        didSet {
            observeEmptyStateForWindowTitle()
            overlayState?.isMoreInfoDialogOpen = onscreenEntityId != nil
        }
    }

    /// Set by `FrontendView` so retry can rebuild the SwiftUI-hosted web view when WebKit is stuck.
    var resetFrontendAction: (() -> Void)?

    /// Owns disconnected empty-state recovery timing. Kept in `HomeAssistantView` so attempts survive reset.
    var reconnectManager: WebViewReconnectManager?

    /// Called after `viewDidLoad` creates the hosted `WKWebView`.
    var onWebViewLoaded: ((WebViewController) -> Void)?

    /// In-flight `loadActiveURLIfNeeded()` attempt and when it started. Repeat calls are skipped
    /// while a recent attempt is running, but an attempt older than
    /// `WebViewController.loadActiveURLStaleInterval` is assumed hung, cancelled, and replaced —
    /// a hung attempt must never block URL loading until the app is killed.
    var loadActiveURLTask: Task<Void, Never>?
    var loadActiveURLTaskStartDate: Date?

    /// Wrapper around the application state; replaceable in tests.
    var isAppInBackground: @MainActor () -> Bool = { ApplicationState.current == .background }

    /// Whether the scene showing this frontend is active, i.e. on screen and receiving events; replaceable
    /// in tests. The scene's state rather than the application's: with several windows open, one frontend
    /// can be in the background while the app as a whole stays active. Without a scene to ask (the view is
    /// not in a window) the application's state is the best answer available.
    var isSceneActive: @MainActor (PlatformWindowScene?) -> Bool = { scene in
        #if os(macOS)
        // A Mac window is the scene; it is "active" while someone can see it. Minimised or hidden with
        // the app, it is as good as backgrounded.
        guard let scene else { return !NSApp.isHidden }
        return scene.isVisible && !scene.isMiniaturized && !NSApp.isHidden
        #else
        guard let scene else { return UIApplication.shared.applicationState == .active }
        return scene.activationState == .foregroundActive
        #endif
    }

    /// Set when the disconnected empty state was asked for while the scene was not active. Nobody could
    /// see it, and the frontend gets its grace period again once the scene is; see `showEmptyState()`.
    var isEmptyStateDeferredUntilActive = false

    /// Set when the scene enters the background and consumed by its next activation, which is how an
    /// activation that follows a backgrounding is told apart from one that follows a system alert.
    var didEnterBackgroundSinceLastActivation = false

    var blankFrontendRecoveryAttempts = 0
    var contentProcessTerminations = 0

    /// Answers the blank-frontend probe instead of the live page; replaceable in tests.
    var hasRenderedFrontendCheck: (@MainActor ((Bool) -> Void) -> Void)?

    /// Where the window's title lands; replaceable in tests, which all share the host process's one scene.
    var applyWindowSceneTitle: @MainActor (PlatformWindowScene, String) -> Void = { windowScene, title in
        windowScene.title = title
    }

    #if os(iOS)
    /// How far down a view must start to clear the window controls; replaceable in tests, which have none.
    var cornerAdaptedSafeAreaTop: @MainActor (UIView) -> CGFloat = { view in
        guard #available(iOS 26, *) else { return view.safeAreaInsets.top }
        return view.directionalEdgeInsets(for: .safeArea(cornerAdaptation: .vertical)).top
    }

    /// Which idiom the frontend is being shown in; only iPad windows get controls drawn over them.
    var userInterfaceIdiom: @MainActor (UIView) -> UIUserInterfaceIdiom = { view in
        view.traitCollection.userInterfaceIdiom
    }
    #endif

    /// Handler for messages sent from the webview to the app
    var webViewExternalMessageHandler: WebViewExternalMessageHandlerProtocol = WebViewExternalMessageHandler(
        improvManager: ImprovManager.shared
    )

    private var kioskCancellables = Set<AnyCancellable>()

    /// Periodically reloads the page while kiosk mode's "Auto reload" is set to an interval.
    private var autoReloadTimer: Timer?

    /// Handler for gestures over the webview
    let webViewGestureHandler = WebViewGestureHandler()

    /// Handler for script messages sent from the webview to the app
    let webViewScriptMessageHandler = WebViewScriptMessageHandler()

    /// Defer showing the empty state until the frontend has been disconnected for
    /// `Current.settingsStore.webViewEmptyStateTimeout` seconds (used by
    /// updateFrontendConnectionState in WebViewController+ProtocolConformance.swift)
    var emptyStateTimer: Timer?

    #if os(macOS)
    /// Drives the find bar; the web view is its client and `findBarContainer` gives the bar its place.
    lazy var textFinder = NSTextFinder()
    lazy var findBarContainer = WebViewFindBarContainer(webViewController: self)
    /// Watches the window's appearance so the frontend can follow a switch between light and dark.
    var appearanceObserver: NSKeyValueObservation?
    #else
    var underlyingPreferredStatusBarStyle: UIStatusBarStyle = .lightContent

    override var prefersHomeIndicatorAutoHidden: Bool {
        Current.settingsStore.fullScreen
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        underlyingPreferredStatusBarStyle
    }

    /// SwiftUI defers status-bar appearance to this embedded controller (`preferredStatusBarStyle` above
    /// works the same way), so `HomeAssistantView`'s `.statusBarHidden` alone has no effect.
    override var prefersStatusBarHidden: Bool {
        WebViewChromeState.resolveStatusBarHidden()
    }

    #if targetEnvironment(macCatalyst)
    override var canBecomeFirstResponder: Bool {
        true
    }

    override var keyCommands: [UIKeyCommand]? {
        func prioritised(_ input: String, _ action: Selector) -> UIKeyCommand {
            let command = UIKeyCommand(input: input, modifierFlags: .command, action: action)
            command.wantsPriorityOverSystemBehavior = true
            return command
        }

        var commands = [
            prioritised("c", #selector(copyCurrentSelectedContent)),
            prioritised("v", #selector(pasteContent)),
            prioritised("x", #selector(cutCurrentSelectedContent)),
            UIKeyCommand(
                input: "c",
                modifierFlags: [.shift, .command],
                action: #selector(copyCurrentSelectedContent)
            ),
            UIKeyCommand(
                input: "v",
                modifierFlags: [.shift, .command],
                action: #selector(pasteContent)
            ),
            UIKeyCommand(
                input: "x",
                modifierFlags: [.shift, .command],
                action: #selector(cutCurrentSelectedContent)
            ),
            UIKeyCommand(
                input: "r",
                modifierFlags: .command,
                action: #selector(refresh)
            ),
        ]

        commands.append(UIKeyCommand(
            input: "f",
            modifierFlags: .command,
            action: #selector(showFindInteraction)
        ))
        commands.append(UIKeyCommand(
            input: "f",
            modifierFlags: [.shift, .command],
            action: #selector(showFindInteraction)
        ))

        return commands
    }
    #endif
    #endif

    // MARK: - Initialization

    init(server: Server, shouldLoadImmediately: Bool = false) {
        self.server = server
        #if os(iOS)
        self.leftEdgePanGestureRecognizer = with(UIScreenEdgePanGestureRecognizer()) {
            $0.edges = .left
        }
        self.rightEdgeGestureRecognizer = with(UIScreenEdgePanGestureRecognizer()) {
            $0.edges = .right
        }
        #endif

        super.init(nibName: nil, bundle: nil)

        userActivity = with(NSUserActivity(activityType: "\(AppConstants.BundleID).frontend")) {
            $0.isEligibleForHandoff = true
        }

        #if os(iOS)
        leftEdgePanGestureRecognizer.addTarget(self, action: #selector(screenEdgeGestureRecognizerAction(_:)))
        rightEdgeGestureRecognizer.addTarget(self, action: #selector(screenEdgeGestureRecognizerAction(_:)))
        #endif

        if shouldLoadImmediately {
            loadViewIfNeeded()
            loadActiveURLIfNeeded()
        }

        webViewExternalMessageHandler.webViewController = self
        webViewGestureHandler.webView = self
        webViewScriptMessageHandler.webView = self
    }

    convenience init?(restoring: WebViewRestorationType?, shouldLoadImmediately: Bool = false) {
        if let server = restoring?.server ?? Current.servers.all.first {
            self.init(server: server)
        } else {
            return nil
        }

        self.initialURL = restoring?.initialURL
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        #if os(iOS)
        tabBarAssistZoomAnchor?.removeFromSuperview()
        #else
        self.appearanceObserver = nil
        textFinder.client = nil
        textFinder.findBarContainer = nil
        #endif
        self.urlObserver = nil
        self.windowTitleObserver = nil
        if let siriExposureObserver {
            NotificationCenter.default.removeObserver(siriExposureObserver)
        }
        onscreenContentTask?.cancel()
        self.tokens.forEach { $0.cancel() }
        autoReloadTimer?.invalidate()
        loadActiveURLTask?.cancel()
    }

    static func makeWebViewConfiguration() -> WKWebViewConfiguration {
        // WebKit reads this when the web view is built, so it has to be settled first.
        WebKitEnhancedSecurity.prepareForConfiguredServers()

        let config = WKWebViewConfiguration()
        #if os(iOS)
        config.allowsInlineMediaPlayback = true
        #endif
        // Avoid interrupting background audio when the frontend loads media-capable elements.
        config.mediaTypesRequiringUserActionForPlayback = Current.settingsStore
            .mediaTypesRequiringUserActionForPlayback
            .wkMediaTypes
        return config
    }

    // MARK: - View Lifecycle

    #if os(macOS)
    /// AppKit has no view to hand a controller that was not loaded from a nib.
    override func loadView() {
        view = NSView()
    }

    // AppKit only gained these two in macOS 14. The extensions shared with iOS rely on them, so they are
    // provided here for the releases before that.
    override var viewIfLoaded: NSView? {
        isViewLoaded ? view : nil
    }

    override func loadViewIfNeeded() {
        _ = view
    }
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()
        #if os(iOS)
        becomeFirstResponder()
        #endif

        observeConnectionNotifications()
        setupKioskModeObservation()
        observeSiriExposureForOnscreenContent()
        // Weakly held; surfaces re-authentication when this server's refresh token is rejected.
        Current.onboardingObservation.register(observer: self)

        #if os(iOS)
        let statusBarView = setupStatusBarView()
        #endif

        let config = Self.makeWebViewConfiguration()

        let userContentController = setupUserContentController()

        guard let wsBridgeJSPath = Bundle.main.path(forResource: "WebSocketBridge", ofType: "js"),
              let wsBridgeJS = try? String(contentsOfFile: wsBridgeJSPath) else {
            fatalError("Couldn't load WebSocketBridge.js for injection to WKWebView!")
        }

        userContentController.addUserScript(WKUserScript(
            source: wsBridgeJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))

        userContentController.addUserScript(.init(
            source: """
                window.addEventListener("error", (e) => {
                    window.webkit.messageHandlers.logError.postMessage({
                        "message": JSON.stringify(e.message),
                        "filename": JSON.stringify(e.filename),
                        "lineno": JSON.stringify(e.lineno),
                        "colno": JSON.stringify(e.colno),
                    });
                });
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        config.userContentController = userContentController
        config.applicationNameForUserAgent = HomeAssistantAPI.applicationNameForUserAgent
        config.defaultWebpagePreferences.preferredContentMode = Current.isCatalyst ? .desktop : .mobile

        webView = WKWebView(frame: view.frame, configuration: config)
        #if os(macOS)
        webView.makeBackgroundTransparent()
        webView.allowsBackForwardNavigationGestures = true
        #else
        webView.isOpaque = false
        #endif
        view.addSubview(webView)

        #if os(iOS)
        setupGestures(numberOfTouchesRequired: 2)
        setupGestures(numberOfTouchesRequired: 3)
        setupEdgeGestures()
        #endif
        setupURLObserver()
        setupWindowTitleObserver()

        webView.navigationDelegate = self
        webView.uiDelegate = self

        #if os(macOS)
        setupWebViewConstraints()
        textFinder.client = webView
        textFinder.findBarContainer = findBarContainer
        textFinder.isIncrementalSearchingEnabled = true
        textFinder.incrementalSearchingShouldDimContentView = true
        observeAppearance()
        #else
        setupWebViewConstraints(statusBarView: statusBarView)

        // Above the web view so it lands where the frontend draws its Assist button; it takes no touches,
        // so the button underneath keeps working. Aligned to the web view so it follows the frontend's offset.
        assistZoomAnchorView = AssistZoomAnchorView.install(in: view, alignedTo: webView)
        #endif

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateWebViewSettingsForNotification),
            name: SettingsStore.webViewRelatedSettingDidChange,
            object: nil
        )
        updateWebViewSettings(reason: .initial)
        styleUI()
        getLatestConfig()

        webView.isInspectable = true

        #if os(iOS)
        webView.isFindInteractionEnabled = true
        #endif

        postOnboardingNotificationPermission()
        checkForLocalSecurityLevelDecisionNeeded()
        onWebViewLoaded?(self)
    }

    #if os(macOS)
    override func viewWillAppear() {
        super.viewWillAppear()
        loadActiveURLIfNeeded()
    }

    /// The Edit > Find menu items: Find Next, Find Previous, Use Selection for Find and the bar itself.
    override func performTextFinderAction(_ sender: Any?) {
        guard let item = sender as? NSMenuItem, let action = NSTextFinder.Action(rawValue: item.tag) else { return }
        textFinder.performAction(action)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateDatabaseAndPanels()
        updateWindowSceneTitle()
        userActivity?.becomeCurrent()
        updateOnscreenContent()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        userActivity?.resignCurrent()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        findBarContainer.layoutIfVisible()
    }

    /// The frontend picks its theme from the colours the app reports, so it has to be told when the
    /// window moves between light and dark.
    private func observeAppearance() {
        appearanceObserver = view.observe(\.effectiveAppearance) { [weak self] _, _ in
            self?.webView?.evaluateJavaScript("notifyThemeColors()", completionHandler: nil)
        }
    }
    #else
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateWindowControlsInset()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateWindowControlsInset()
    }

    /// Workaround for webview rotation issues: https://github.com/Telerik-Verified-Plugins/WKWebView/pull/263
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.webView?.setNeedsLayout()
            self.webView?.layoutIfNeeded()
        }, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadActiveURLIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateDatabaseAndPanels()
        updateWindowSceneTitle()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        updateWindowSceneTitle()
    }

    override func viewWillDisappear(_ animated: Bool) {
        userActivity?.resignCurrent()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            webView.evaluateJavaScript("notifyThemeColors()", completionHandler: nil)
        }

        // The strip depends on the horizontal size class, which changes with window resizes and
        // foldables folding/unfolding — not just once per device.
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
            updateThemedStatusBar()
        }
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            let action = Current.settingsStore.gestures[.shake] ?? .none
            webViewGestureHandler.handleGestureAction(action)
        }
    }
    #endif
}

private extension Set<SettingsStore.MediaTypeRequiringUserActionForPlayback> {
    var wkMediaTypes: WKAudiovisualMediaTypes {
        var mediaTypes: WKAudiovisualMediaTypes = []

        if contains(.audio) {
            mediaTypes.insert(.audio)
        }
        if contains(.video) {
            mediaTypes.insert(.video)
        }

        return mediaTypes
    }
}

// MARK: - Kiosk mode

extension WebViewController {
    func setupKioskModeObservation() {
        Current.kiosk.settingsPublisher
            .map { $0.enabled && $0.removeHeaderAndSidebar }
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateFrontendKioskMode()
            }
            .store(in: &kioskCancellables)

        Current.kiosk.settingsPublisher
            .map { $0.enabled && $0.hideStatusBar }
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                #if os(iOS)
                self?.setNeedsStatusBarAppearanceUpdate()
                #endif
            }
            .store(in: &kioskCancellables)

        // (Re)schedule the auto-reload timer. Not dropped, so the initial value arms it on cold start.
        Current.kiosk.settingsPublisher
            .map { $0.enabled ? $0.autoReload : .never }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] interval in
                self?.applyAutoReload(interval)
            }
            .store(in: &kioskCancellables)
    }

    private func applyAutoReload(_ interval: KioskAutoReloadInterval) {
        autoReloadTimer?.invalidate()
        autoReloadTimer = nil
        guard let seconds = interval.timeInterval else { return }
        autoReloadTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch connectionState {
                case .connected, .loaded:
                    reload()
                case .disconnected, .unknown:
                    if overlayState?.emptyState != nil {
                        recoverDisconnectedFrontend()
                    }
                case .authInvalid:
                    break
                }
            }
        }
    }

    func updateFrontendKioskMode() {
        let enable = Current.kioskSettings.enabled && Current.kioskSettings.removeHeaderAndSidebar
        webViewExternalMessageHandler.sendExternalBusCommandWithRetry(
            command: .kioskModeSet,
            payload: ["enable": enable]
        )
    }
}
