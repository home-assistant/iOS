import AVFoundation
import AVKit
import CoreLocation
import HAKit
import Improv_iOS
import KeychainAccess
import MBProgressHUD
import PromiseKit
import Shared
import SwiftMessages
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

    var emptyStateView: UIView?
    let emptyStateTransitionDuration: TimeInterval = 0.3

    var statusBarView: UIView?
    var webViewTopConstraint: NSLayoutConstraint?

    var initialURL: URL?
    var statusBarButtonsStack: UIStackView?
    var lastNavigationWasServerError = false
    var reconnectBackgroundTimer: Timer? {
        willSet {
            if reconnectBackgroundTimer != newValue {
                reconnectBackgroundTimer?.invalidate()
            }
        }
    }

    var connectionState: FrontEndConnectionState = .unknown

    var loadActiveURLIfNeededInProgress = false

    /// Track the timestamp of the last pull-to-refresh action
    var lastPullToRefreshTimestamp: Date?

    /// Handler for messages sent from the webview to the app
    var webViewExternalMessageHandler: WebViewExternalMessageHandlerProtocol = WebViewExternalMessageHandler(
        improvManager: ImprovManager.shared
    )

    /// Handler for gestures over the webview
    let webViewGestureHandler = WebViewGestureHandler()

    /// Handler for script messages sent from the webview to the app
    let webViewScriptMessageHandler = WebViewScriptMessageHandler()

    /// Defer showing the empty state until disconnected for 10 seconds (used by
    /// updateFrontendConnectionState in WebViewController+ProtocolConformance.swift)
    var emptyStateTimer: Timer?

    /// Frontend notifies when connection is established or not
    /// Each navigation resets this to false so we can show the empty state
    var isConnected = false

    var underlyingPreferredStatusBarStyle: UIStatusBarStyle = .lightContent

    override var prefersStatusBarHidden: Bool {
        Current.settingsStore.fullScreen
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        Current.settingsStore.fullScreen
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        underlyingPreferredStatusBarStyle
    }

    #if targetEnvironment(macCatalyst)
    override var keyCommands: [UIKeyCommand]? {
        var commands = [
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
                input: "c",
                modifierFlags: .command,
                action: #selector(copyCurrentSelectedContent)
            ),
            UIKeyCommand(
                input: "v",
                modifierFlags: .command,
                action: #selector(pasteContent)
            ),
            UIKeyCommand(
                input: "r",
                modifierFlags: .command,
                action: #selector(refresh)
            ),
        ]

        // Add find command for iOS 16+
        if #available(iOS 16.0, *) {
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
        }

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
        removeEmptyStateObservations()
        self.urlObserver = nil
        self.tokens.forEach { $0.cancel() }
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        becomeFirstResponder()

        observeConnectionNotifications()

        let statusBarView = setupStatusBarView()

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let userContentController = setupUserContentController()

        guard let wsBridgeJSPath = Bundle.main.path(forResource: "WebSocketBridge", ofType: "js"),
              let wsBridgeJS = try? String(contentsOfFile: wsBridgeJSPath) else {
            fatalError("Couldn't load WebSocketBridge.js for injection to WKWebView!")
        }

        userContentController.addUserScript(WKUserScript(
            source: wsBridgeJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
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
            forMainFrameOnly: false
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
        setupEmptyState()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateWebViewSettingsForNotification),
            name: SettingsStore.webViewRelatedSettingDidChange,
            object: nil
        )
        updateWebViewSettings(reason: .initial)
        styleUI()
        getLatestConfig()

        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        // Enable find interaction for iOS 16+
        if #available(iOS 16.0, *) {
            webView.isFindInteractionEnabled = true
        }

        postOnboardingNotificationPermission()
        emptyStateObservations()
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
