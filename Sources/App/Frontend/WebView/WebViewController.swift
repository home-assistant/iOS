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

    var urlObserver: NSKeyValueObservation?
    var tokens = [HACancellable]()

    let refreshControl = UIRefreshControl()
    let leftEdgePanGestureRecognizer: UIScreenEdgePanGestureRecognizer
    let rightEdgeGestureRecognizer: UIScreenEdgePanGestureRecognizer

    var statusBarView: UIView?
    var webViewTopConstraint: NSLayoutConstraint?
    var bannerPresenter: any BannerPresenter = DefaultBannerPresenter()
    var latestLoadError: Error?

    var initialURL: URL?
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

    /// Set by `FrontendView`; lets connection/URL state drive SwiftUI overlays in `HomeAssistantView`
    /// instead of UIKit modals presented from here.
    var overlayState: WebFrontendOverlayState?

    /// Set by `FrontendView` so retry can rebuild the SwiftUI-hosted web view when WebKit is stuck.
    var resetFrontendAction: (() -> Void)?

    /// Owns disconnected empty-state recovery timing. Kept in `HomeAssistantView` so attempts survive reset.
    var reconnectManager: WebViewReconnectManager?

    /// In-flight `loadActiveURLIfNeeded()` attempt and when it started. Repeat calls are skipped
    /// while a recent attempt is running, but an attempt older than
    /// `WebViewController.loadActiveURLStaleInterval` is assumed hung, cancelled, and replaced —
    /// a hung attempt must never block URL loading until the app is killed.
    var loadActiveURLTask: Task<Void, Never>?
    var loadActiveURLTaskStartDate: Date?

    /// Wrapper around the application state; replaceable in tests.
    var isAppInBackground: @MainActor () -> Bool = { UIApplication.shared.applicationState == .background }

    /// Track the timestamp of the last pull-to-refresh action
    var lastPullToRefreshTimestamp: Date?

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

    #if targetEnvironment(macCatalyst)
    override var canBecomeFirstResponder: Bool { true }

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

    init(server: Server, shouldLoadImmediately: Bool = false) {
        self.server = server
        self.leftEdgePanGestureRecognizer = with(UIScreenEdgePanGestureRecognizer()) {
            $0.edges = .left
        }
        self.rightEdgeGestureRecognizer = with(UIScreenEdgePanGestureRecognizer()) {
            $0.edges = .right
        }

        super.init(nibName: nil, bundle: nil)

        userActivity = with(NSUserActivity(activityType: "\(AppConstants.BundleID).frontend")) {
            $0.isEligibleForHandoff = true
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
        self.urlObserver = nil
        self.tokens.forEach { $0.cancel() }
        autoReloadTimer?.invalidate()
        loadActiveURLTask?.cancel()
    }

    static func makeWebViewConfiguration() -> WKWebViewConfiguration {
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
        setupEdgeGestures()
        setupURLObserver()

        webView.navigationDelegate = self
        webView.uiDelegate = self

        setupWebViewConstraints(statusBarView: statusBarView)
        setupPullToRefresh()

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
    }

    // Workaround for webview rotation issues: https://github.com/Telerik-Verified-Plugins/WKWebView/pull/263
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
    }

    override func viewWillDisappear(_ animated: Bool) {
        userActivity?.resignCurrent()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            webView.evaluateJavaScript("notifyThemeColors()", completionHandler: nil)
        }
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            let action = Current.settingsStore.gestures[.shake] ?? .openDebug
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
                case .connected:
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
