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
import UIKit
@preconcurrency import WebKit

final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    var webView: WKWebView!
    let server: Server
    /// Whether this is the app's frontend or a native modal over it; see `WebViewControllerRole`.
    let role: WebViewControllerRole
    /// Called with the frontend path a modal was asked to leave for, before it dismisses.
    var onNativeModalNavigation: ((String) -> Void)?
    /// Called each time a modal's frontend becomes ready to show, on its first load and on every
    /// reconnection after it drops. `frontend/loaded` arrives once per page load, so a modal that
    /// loses its connection while it waits would never hear about the recovery otherwise.
    var onNativeModalReady: (() -> Void)?
    /// Called with everything a modal's frontend changes about it after it is up.
    var onNativeModalUpdate: ((NativeModalUpdate) -> Void)?
    /// Called with the entity a modal's page is showing, or nil when it stops showing one. A modal
    /// publishes no activity of its own, so its host carries this for Siri.
    var onNativeModalOnscreenEntity: ((String?) -> Void)?

    var urlObserver: NSKeyValueObservation?
    var windowTitleObserver: NSKeyValueObservation?
    /// Watches `.siriEntityExposureDidChange` so what is published on `userActivity` follows the
    /// user's Siri exposure setting; see `WebViewController+OnscreenContent`.
    var siriExposureObserver: NSObjectProtocol?
    /// The entity the frontend's more-info dialog is showing, reported over the external bus.
    var onscreenEntityId: String?
    /// The path the dialog opened over, so a route change is recognised as having closed it.
    var onscreenEntityPath: String?
    /// The in-flight publish of what is on screen, cancelled when a newer one replaces it.
    var onscreenContentTask: Task<Void, Never>?
    var emptyStateTitleObserver: AnyCancellable?
    var tokens = [HACancellable]()

    let leftEdgePanGestureRecognizer: UIScreenEdgePanGestureRecognizer
    let rightEdgeGestureRecognizer: UIScreenEdgePanGestureRecognizer

    var statusBarView: UIView?
    /// Stands in for the frontend's Assist button as the zoom transition's source; see `AssistZoomAnchorView`.
    var assistZoomAnchorView: UIView?
    var pendingAssistZoomSourceView: UIView?
    /// An overlay presented from the window while this view was off screen behind the App Labs tab bar.
    weak var detachedOverlayController: UIViewController?
    var tabBarAssistZoomAnchor: AssistZoomAnchorView?
    var webViewTopConstraint: NSLayoutConstraint?
    /// Pins the bottom of `statusBarView`; on iOS it follows the web view's top edge.
    var statusBarBottomConstraint: NSLayoutConstraint?
    var bannerPresenter: any BannerPresenter = DefaultBannerPresenter()
    var latestLoadError: Error?

    var initialURL: URL?
    var initialURLPath: String?
    var statusBarButtonsStack: UIStackView?
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
    var isAppInBackground: @MainActor () -> Bool = { UIApplication.shared.applicationState == .background }

    var blankFrontendRecoveryAttempts = 0
    var contentProcessTerminations = 0

    /// Answers the blank-frontend probe instead of the live page; replaceable in tests.
    var hasRenderedFrontendCheck: (@MainActor ((Bool) -> Void) -> Void)?

    /// Where the window's title lands; replaceable in tests, which all share the host process's one scene.
    var applyWindowSceneTitle: @MainActor (UIWindowScene, String) -> Void = { windowScene, title in
        windowScene.title = title
    }

    /// How far down a view must start to clear the window controls; replaceable in tests, which have none.
    var cornerAdaptedSafeAreaTop: @MainActor (UIView) -> CGFloat = { view in
        guard #available(iOS 26, *) else { return view.safeAreaInsets.top }
        return view.directionalEdgeInsets(for: .safeArea(cornerAdaptation: .vertical)).top
    }

    /// Which idiom the frontend is being shown in; only iPad windows get controls drawn over them.
    var userInterfaceIdiom: @MainActor (UIView) -> UIUserInterfaceIdiom = { view in
        view.traitCollection.userInterfaceIdiom
    }

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

    // MARK: - Initialization

    init(server: Server, role: WebViewControllerRole = .mainFrontend, shouldLoadImmediately: Bool = false) {
        self.server = server
        self.role = role
        self.leftEdgePanGestureRecognizer = with(UIScreenEdgePanGestureRecognizer()) {
            $0.edges = .left
        }
        self.rightEdgeGestureRecognizer = with(UIScreenEdgePanGestureRecognizer()) {
            $0.edges = .right
        }

        super.init(nibName: nil, bundle: nil)

        // A standalone sheet publishes nothing of its own: the frontend underneath keeps carrying
        // the page for Handoff, and the entity the sheet shows for Siri.
        if role.isMainFrontend {
            userActivity = with(NSUserActivity(activityType: "\(AppConstants.BundleID).frontend")) {
                $0.isEligibleForHandoff = true
            }
        }

        leftEdgePanGestureRecognizer.addTarget(self, action: #selector(screenEdgeGestureRecognizerAction(_:)))
        rightEdgeGestureRecognizer.addTarget(self, action: #selector(screenEdgeGestureRecognizerAction(_:)))

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
        tabBarAssistZoomAnchor?.removeFromSuperview()
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
        config.allowsInlineMediaPlayback = true
        // Avoid interrupting background audio when the frontend loads media-capable elements.
        config.mediaTypesRequiringUserActionForPlayback = Current.settingsStore
            .mediaTypesRequiringUserActionForPlayback
            .wkMediaTypes
        return config
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        becomeFirstResponder()

        observeConnectionNotifications()
        setupKioskModeObservation()
        observeSiriExposureForOnscreenContent()
        // Weakly held; surfaces re-authentication when this server's refresh token is rejected.
        Current.onboardingObservation.register(observer: self)

        let statusBarView = setupStatusBarView()

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

        webView = WKWebView(frame: view!.frame, configuration: config)
        webView.isOpaque = false
        view!.addSubview(webView)

        setupGestures(numberOfTouchesRequired: 2)
        setupGestures(numberOfTouchesRequired: 3)
        if role.isMainFrontend {
            // The edge gestures toggle the sidebar the standalone page does not have, and would fight
            // the sheet's own swipe; where the frontend is, and what it is titled, is the app's page.
            setupEdgeGestures()
            setupURLObserver()
            setupWindowTitleObserver()
        }

        webView.navigationDelegate = self
        webView.uiDelegate = self

        setupWebViewConstraints(statusBarView: statusBarView)

        // Above the web view so it lands where the frontend draws its Assist button; it takes no touches,
        // so the button underneath keeps working. Aligned to the web view so it follows the frontend's offset.
        assistZoomAnchorView = AssistZoomAnchorView.install(in: view, alignedTo: webView)

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

        webView.isFindInteractionEnabled = true

        postOnboardingNotificationPermission()
        checkForLocalSecurityLevelDecisionNeeded()
        onWebViewLoaded?(self)
    }

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
                self?.setNeedsStatusBarAppearanceUpdate()
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
        // The standalone page has no header or sidebar to remove.
        guard role.isMainFrontend else { return }
        let enable = Current.kioskSettings.enabled && Current.kioskSettings.removeHeaderAndSidebar
        webViewExternalMessageHandler.sendExternalBusCommandWithRetry(
            command: .kioskModeSet,
            payload: ["enable": enable]
        )
    }
}
