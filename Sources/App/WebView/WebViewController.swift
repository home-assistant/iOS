import Alamofire
import AVFoundation
import AVKit
import CoreLocation
import HAKit
import KeychainAccess
import MBProgressHUD
import PromiseKit
import Shared
import SwiftMessages
import UIKit
import WebKit

class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UIViewControllerRestoration {
    var webView: WKWebView!

    let server: Server

    var urlObserver: NSKeyValueObservation?
    var tokens = [HACancellable]()

    let refreshControl = UIRefreshControl()

    var keepAliveTimer: Timer?
    private var initialURL: URL?

    static func viewController(
        withRestorationIdentifierPath identifierComponents: [String],
        coder: NSCoder
    ) -> UIViewController? {
        if #available(iOS 13, *) {
            return nil
        } else {
            return WebViewController(restoring: .coder(coder))
        }
    }

    let settingsButton: UIButton! = {
        let button = UIButton()
        button.setImage(
            MaterialDesignIcons.cogIcon.image(ofSize: CGSize(width: 36, height: 36), color: .white),
            for: .normal
        )
        button.accessibilityLabel = L10n.Settings.NavigationBar.title
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        button.setBackgroundImage(
            UIImage(size: CGSize(width: 1, height: 1), color: UIColor(red: 1.00, green: 0.60, blue: 0.00, alpha: 1.0)),
            for: .normal
        )

        // size isn't affected by any trait changes, so we can grab the height once and not worry about it changing
        let desiredSize = button.systemLayoutSizeFitting(.zero)
        button.layer.cornerRadius = ceil(desiredSize.height / 2.0)
        button.layer.masksToBounds = true

        button.translatesAutoresizingMaskIntoConstraints = false
        if Current.appConfiguration == .FastlaneSnapshot {
            button.alpha = 0
        }
        return button
    }()

    enum RestorableStateKey: String {
        case lastURL
        case server
    }

    override func encodeRestorableState(with coder: NSCoder) {
        if #available(iOS 13, *) {
        } else {
            super.encodeRestorableState(with: coder)
            coder.encode(webView.url as NSURL?, forKey: RestorableStateKey.lastURL.rawValue)
            coder.encode(server.identifier.rawValue as NSString?, forKey: RestorableStateKey.server.rawValue)
        }
    }

    override func decodeRestorableState(with coder: NSCoder) {
        if #available(iOS 13, *) {
        } else {
            // we do this manually so that we can get the values earlier
            super.decodeRestorableState(with: coder)
        }
    }

    override var prefersStatusBarHidden: Bool {
        Current.settingsStore.fullScreen
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        Current.settingsStore.fullScreen
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 13, *) {
        } else {
            restorationClass = Self.self
            restorationIdentifier = String(describing: Self.self)
        }

        becomeFirstResponder()

        for name: Notification.Name in [
            HomeAssistantAPI.didConnectNotification,
            UIApplication.didBecomeActiveNotification,
        ] {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(connectionInfoDidChange),
                name: name,
                object: nil
            )
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scheduleReconnectBackgroundTimer),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        tokens.append(server.observe { [weak self] _ in
            self?.connectionInfoDidChange()
        })

        let statusBarView = UIView()
        statusBarView.tag = 111

        view.addSubview(statusBarView)

        statusBarView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        statusBarView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        statusBarView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        statusBarView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true

        statusBarView.translatesAutoresizingMaskIntoConstraints = false

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "getExternalAuth")
        userContentController.add(self, name: "revokeExternalAuth")
        userContentController.add(self, name: "externalBus")
        userContentController.add(self, name: "updateThemeColors")
        userContentController.add(self, name: "logError")

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
        // "Mobile/BUILD_NUMBER" is what CodeMirror sniffs for to decide iOS or not; other things likely look for Safari
        config.applicationNameForUserAgent = HomeAssistantAPI.userAgent + " Mobile/HomeAssistant, like Safari"

        webView = WKWebView(frame: view!.frame, configuration: config)
        webView.isOpaque = false
        view!.addSubview(webView)

        for direction: UISwipeGestureRecognizer.Direction in [.left, .right] {
            webView.addGestureRecognizer(with(UISwipeGestureRecognizer(target: self, action: #selector(swipe(_:)))) {
                $0.numberOfTouchesRequired = 2
                $0.direction = direction
            })
        }

        urlObserver = webView.observe(\.url) { [weak self] webView, _ in
            guard let self = self else { return }

            guard let currentURL = webView.url?.absoluteString.replacingOccurrences(of: "?external_auth=1", with: ""),
                  let cleanURL = URL(string: currentURL), let scheme = cleanURL.scheme else {
                return
            }

            guard ["http", "https"].contains(scheme) else {
                Current.Log.warning("Was going to provide invalid URL to NSUserActivity! \(currentURL)")
                return
            }

            self.userActivity?.webpageURL = cleanURL
            self.userActivity?.userInfo = [
                RestorableStateKey.lastURL.rawValue: cleanURL,
                RestorableStateKey.server.rawValue: self.server.identifier.rawValue,
            ]
            self.userActivity?.becomeCurrent()
        }

        webView.navigationDelegate = self
        webView.uiDelegate = self

        webView.translatesAutoresizingMaskIntoConstraints = false

        webView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        webView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        webView.topAnchor.constraint(equalTo: statusBarView.bottomAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        if !Current.isCatalyst {
            // refreshing is handled by menu/keyboard shortcuts
            refreshControl.addTarget(self, action: #selector(pullToRefresh(_:)), for: .valueChanged)
            webView.scrollView.addSubview(refreshControl)
            webView.scrollView.bounces = true
        }

        settingsButton.addTarget(self, action: #selector(openSettingsView(_:)), for: .touchDown)

        view.addSubview(settingsButton)

        view.bottomAnchor.constraint(equalTo: settingsButton.bottomAnchor, constant: 16.0).isActive = true
        view.rightAnchor.constraint(equalTo: settingsButton.rightAnchor, constant: 16.0).isActive = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateWebViewSettingsForNotification),
            name: SettingsStore.webViewRelatedSettingDidChange,
            object: nil
        )
        updateWebViewSettings(reason: .initial)

        styleUI()
    }

    public func showSettingsViewController() {
        if #available(iOS 13, *), Current.sceneManager.supportsMultipleScenes, Current.isCatalyst {
            Current.sceneManager.activateAnyScene(for: .settings)
        } else {
            let settingsView = SettingsViewController()
            settingsView.hidesBottomBarWhenPushed = true
            let navController = UINavigationController(rootViewController: settingsView)
            navigationController?.present(navController, animated: true, completion: nil)
        }
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

    override func viewWillDisappear(_ animated: Bool) {
        userActivity?.resignCurrent()
    }

    enum RestorationType {
        case userActivity(NSUserActivity)
        case coder(NSCoder)
        case server(Server)

        init?(_ userActivity: NSUserActivity?) {
            if let userActivity = userActivity {
                self = .userActivity(userActivity)
            } else {
                return nil
            }
        }

        var initialURL: URL? {
            switch self {
            case let .userActivity(userActivity):
                return userActivity.userInfo?[RestorableStateKey.lastURL.rawValue] as? URL
            case let .coder(coder):
                return coder.decodeObject(of: NSURL.self, forKey: RestorableStateKey.lastURL.rawValue) as URL?
            case .server:
                return nil
            }
        }

        var server: Server? {
            let serverRawValue: String?

            switch self {
            case let .userActivity(userActivity):
                serverRawValue = userActivity.userInfo?[RestorableStateKey.server.rawValue] as? String
            case let .coder(coder):
                serverRawValue = coder.decodeObject(
                    of: NSString.self,
                    forKey: RestorableStateKey.server.rawValue
                ) as String?
            case let .server(server):
                return server
            }

            return Current.servers.server(forServerIdentifier: serverRawValue)
        }
    }

    init(server: Server, shouldLoadImmediately: Bool = false) {
        self.server = server

        super.init(nibName: nil, bundle: nil)

        userActivity = with(NSUserActivity(activityType: "\(Constants.BundleID).frontend")) {
            $0.isEligibleForHandoff = true
        }

        if shouldLoadImmediately {
            loadViewIfNeeded()
            loadActiveURLIfNeeded()
        }
    }

    convenience init?(restoring: RestorationType?, shouldLoadImmediately: Bool = false) {
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
    }

    private func styleUI() {
        precondition(isViewLoaded && webView != nil)

        let cachedColors = ThemeColors.cachedThemeColors(for: traitCollection)

        webView?.backgroundColor = cachedColors[.primaryBackgroundColor]
        webView?.scrollView.backgroundColor = cachedColors[.primaryBackgroundColor]

        if let statusBarView = view.viewWithTag(111) {
            statusBarView.backgroundColor = cachedColors[.appHeaderBackgroundColor]
        }

        refreshControl.tintColor = cachedColors[.primaryColor]

        let headerBackgroundIsLight = cachedColors[.appHeaderBackgroundColor].isLight
        if #available(iOS 13, *) {
            self.underlyingPreferredStatusBarStyle = headerBackgroundIsLight ? .darkContent : .lightContent
        } else {
            underlyingPreferredStatusBarStyle = headerBackgroundIsLight ? .default : .lightContent
        }

        setNeedsStatusBarAppearanceUpdate()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if #available(iOS 13, *), traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            webView.evaluateJavaScript("notifyThemeColors()", completionHandler: nil)
        }
    }

    public func open(inline url: URL) {
        loadViewIfNeeded()

        // these paths do not show frontend pages, and so we don't want to display them in our webview
        // otherwise the user will get stuck. e.g. /api is loaded by frigate to show video clips and images
        let ignoredPaths = [
            "/api",
            "/static",
            "/hacsfiles",
            "/local",
        ]

        if ignoredPaths.allSatisfy({ !url.path.hasPrefix($0) }) {
            webView.load(URLRequest(url: url))
        } else {
            openURLInBrowser(url, self)
        }
    }

    private var lastNavigationWasServerError = false

    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let result = server.info.connection.evaluate(challenge)
        completionHandler(result.0, result.1)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            openURLInBrowser(navigationAction.request.url!, self)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        refreshControl.endRefreshing()
        if let err = error as? URLError {
            if err.code != .cancelled {
                Current.Log.error("Failure during nav: \(err)")
            }

            if !error.isCancelled {
                showSwiftMessage(error: error)
            }
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        refreshControl.endRefreshing()
        if let err = error as? URLError {
            if err.code != .cancelled {
                Current.Log.error("Failure during content load: \(error)")
            }

            if !error.isCancelled {
                showSwiftMessage(error: error)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refreshControl.endRefreshing()

        // in case the view appears again, don't reload
        initialURL = nil

        updateWebViewSettings(reason: .load)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        lastNavigationWasServerError = false

        guard navigationResponse.isForMainFrame else {
            // we don't need to modify the response if it's for a sub-frame
            decisionHandler(.allow)
            return
        }

        guard let httpResponse = navigationResponse.response as? HTTPURLResponse, httpResponse.statusCode >= 400 else {
            // not an error response, we don't need to inspect at all
            decisionHandler(.allow)
            return
        }

        lastNavigationWasServerError = true

        // error response, let's inspect if it's restoring a page or normal navigation
        if navigationResponse.response.url != initialURL {
            // just a normal loading error
            decisionHandler(.allow)
        } else {
            // first: clear that saved url, it's bad
            initialURL = nil

            // it's for the restored page, let's load the default url

            if let webviewURL = server.info.connection.webviewURL() {
                decisionHandler(.cancel)
                webView.load(URLRequest(url: webviewURL))
            } else {
                // we don't have anything we can do about this
                decisionHandler(.allow)
            }
        }
    }

    // WKUIDelegate
    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let style: UIAlertController.Style = {
            switch webView.traitCollection.userInterfaceIdiom {
            case .carPlay, .phone, .tv:
                return .actionSheet
            case .mac:
                return .alert
            case .pad, .unspecified:
                // without a touch to tell us where, an action sheet in the middle of the screen isn't great
                return .alert
            @unknown default:
                return .alert
            }
        }()

        let alertController = UIAlertController(title: nil, message: message, preferredStyle: style)

        alertController.addAction(UIAlertAction(title: L10n.Alerts.Confirm.ok, style: .default, handler: { _ in
            completionHandler(true)
        }))

        alertController.addAction(UIAlertAction(title: L10n.Alerts.Confirm.cancel, style: .cancel, handler: { _ in
            completionHandler(false)
        }))

        if presentedViewController != nil {
            Current.Log.error("attempted to present an alert when already presenting, bailing")
            completionHandler(false)
        } else {
            present(alertController, animated: true, completion: nil)
        }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)

        alertController.addTextField { textField in
            textField.text = defaultText
        }

        alertController.addAction(UIAlertAction(title: L10n.Alerts.Prompt.ok, style: .default, handler: { _ in
            if let text = alertController.textFields?.first?.text {
                completionHandler(text)
            } else {
                completionHandler(defaultText)
            }
        }))

        alertController.addAction(UIAlertAction(title: L10n.Alerts.Prompt.cancel, style: .cancel, handler: { _ in
            completionHandler(nil)
        }))

        if presentedViewController != nil {
            Current.Log.error("attempted to present an alert when already presenting, bailing")
            completionHandler(nil)
        } else {
            present(alertController, animated: true, completion: nil)
        }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: L10n.Alerts.Alert.ok, style: .default, handler: { _ in
            completionHandler()
        }))

        alertController.popoverPresentationController?.sourceView = self.webView

        if presentedViewController != nil {
            Current.Log.error("attempted to present an alert when already presenting, bailing")
            completionHandler()
        } else {
            present(alertController, animated: true, completion: nil)
        }
    }

    @available(iOS 15, *)
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        decisionHandler(.grant)
    }

    @objc private func connectionInfoDidChange() {
        DispatchQueue.main.async { [self] in
            loadActiveURLIfNeeded()
        }
    }

    @objc private func loadActiveURLIfNeeded() {
        guard let webviewURL = server.info.connection.webviewURL() else {
            Current.Log.info("not loading, no url")
            return
        }

        guard webView.url == nil || webView.url?.baseIsEqual(to: webviewURL) == false else {
            // we also tell the webview -- maybe it failed to connect itself? -- to refresh if needed
            webView.evaluateJavaScript("checkForMissingHassConnectionAndReload()", completionHandler: nil)
            return
        }

        guard UIApplication.shared.applicationState != .background else {
            Current.Log.info("not loading, in background")
            return
        }

        // if we aren't showing a url or it's an incorrect url, update it -- otherwise, leave it alone
        let request: URLRequest

        if Current.settingsStore.restoreLastURL,
           let initialURL = initialURL, initialURL.baseIsEqual(to: webviewURL) {
            Current.Log.info("restoring initial url path: \(initialURL.path)")
            request = URLRequest(url: initialURL)
        } else {
            Current.Log.info("loading default url path: \(webviewURL.path)")
            request = URLRequest(url: webviewURL)
        }

        webView.load(request)
    }

    @objc private func refresh() {
        // called via menu/keyboard shortcut too
        if let webviewURL = server.info.connection.webviewURL() {
            if webView.url?.baseIsEqual(to: webviewURL) == true, !lastNavigationWasServerError {
                webView.reload()
            } else {
                webView.load(URLRequest(url: webviewURL))
            }
        }
    }

    @objc private func swipe(_ gesture: UISwipeGestureRecognizer) {
        let icon: MaterialDesignIcons

        if gesture.direction == .left, webView.canGoForward {
            _ = webView.goForward()
            icon = .arrowRightIcon
        } else if gesture.direction == .right, webView.canGoBack {
            _ = webView.goBack()
            icon = .arrowLeftIcon
        } else {
            // the returned WKNavigation doesn't appear to be nil/non-nil based on whether forward/back occurred
            return
        }

        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud.isUserInteractionEnabled = false
        hud.customView = with(IconImageView(frame: CGRect(x: 0, y: 0, width: 37, height: 37))) {
            $0.iconDrawable = icon
        }
        hud.mode = .customView
        hud.hide(animated: true, afterDelay: 1.0)
    }

    @objc private func updateSensors() {
        // called via menu/keyboard shortcut too
        firstly {
            HomeAssistantAPI.manuallyUpdate(
                applicationState: UIApplication.shared.applicationState,
                type: .userRequested
            )
        }.catch { [weak self] error in
            self?.showSwiftMessage(error: error)
        }
    }

    @objc func pullToRefresh(_ sender: UIRefreshControl) {
        refresh()
        updateSensors()
    }

    private func swiftMessagesConfig() -> SwiftMessages.Config {
        var config = SwiftMessages.Config()

        config.presentationContext = .viewController(self)
        config.duration = .forever
        config.presentationStyle = .bottom
        config.dimMode = .gray(interactive: true)
        config.dimModeAccessibilityLabel = L10n.cancelLabel

        return config
    }

    func show(alert: ServerAlert) {
        Current.Log.info("showing alert \(alert)")

        var config = swiftMessagesConfig()
        config.eventListeners.append({ event in
            switch event {
            case .didHide:
                Current.serverAlerter.markHandled(alert: alert)
            default:
                break
            }
        })

        let view = MessageView.viewFromNib(layout: .messageView)
        view.configureTheme(
            backgroundColor: UIColor(red: 1.000, green: 0.596, blue: 0.000, alpha: 1.0),
            foregroundColor: .white
        )
        view.configureContent(
            title: nil,
            body: alert.message,
            iconImage: nil,
            iconText: nil,
            buttonImage: nil,
            buttonTitle: L10n.openLabel,
            buttonTapHandler: { _ in
                UIApplication.shared.open(alert.url, options: [:], completionHandler: nil)
                SwiftMessages.hide()
            }
        )

        SwiftMessages.show(config: config, view: view)
    }

    func showSwiftMessage(error: Error, duration: SwiftMessages.Duration = .seconds(seconds: 15)) {
        Current.Log.error(error)

        let nsError = error as NSError

        var config = swiftMessagesConfig()
        config.duration = duration

        let view = MessageView.viewFromNib(layout: .messageView)
        view.configureTheme(.error)
        view.configureContent(
            title: error.localizedDescription,
            body: "\(nsError.domain) \(nsError.code)",
            iconImage: nil,
            iconText: nil,
            buttonImage: nil,
            buttonTitle: L10n.okLabel,
            buttonTapHandler: { _ in
                SwiftMessages.hide()
            }
        )
        view.titleLabel?.numberOfLines = 0
        view.bodyLabel?.numberOfLines = 0

        SwiftMessages.show(config: config, view: view)
    }

    @objc func openSettingsView(_ sender: UIButton) {
        showSettingsViewController()
    }

    private var underlyingPreferredStatusBarStyle: UIStatusBarStyle = .lightContent
    override var preferredStatusBarStyle: UIStatusBarStyle {
        underlyingPreferredStatusBarStyle
    }

    @objc private func updateWebViewSettingsForNotification() {
        updateWebViewSettings(reason: .settingChange)
    }

    private enum WebViewSettingsUpdateReason {
        case initial
        case settingChange
        case load
    }

    private func updateWebViewSettings(reason: WebViewSettingsUpdateReason) {
        Current.Log.info("updating web view settings for \(reason)")

        // iOS 14's `pageZoom` property is almost this, but not quite - it breaks the layout as well
        // This is quasi-private API that has existed since pre-iOS 10, but the implementation
        // changed in iOS 12 to be like the +/- zoom buttons in Safari, which scale content without
        // resizing the scrolling viewport.
        let viewScale = Current.settingsStore.pageZoom.viewScaleValue
        Current.Log.info("setting view scale to \(viewScale)")
        webView.setValue(viewScale, forKey: "viewScale")

        if !Current.isCatalyst {
            let zoomValue = Current.settingsStore.pinchToZoom ? "true" : "false"
            webView.evaluateJavaScript("setOverrideZoomEnabled(\(zoomValue))", completionHandler: nil)
        }

        if reason == .settingChange {
            setNeedsStatusBarAppearanceUpdate()
            setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
    }

    private var reconnectBackgroundTimer: Timer? {
        willSet {
            if reconnectBackgroundTimer != newValue {
                reconnectBackgroundTimer?.invalidate()
            }
        }
    }

    @objc private func scheduleReconnectBackgroundTimer() {
        precondition(Thread.isMainThread)

        guard isViewLoaded, server.info.version >= .externalBusCommandRestart else { return }

        // On iOS 15, Apple switched to using NSURLSession's WebSocket implementation, which is pretty bad at detecting
        // any kind of networking failure. Even more troubling, it doesn't realize there's a failure due to background
        // so it spends dozens of seconds waiting for a connection reset externally.
        //
        // We work around this by detecting being in the background for long enough that it's likely the connection will
        // need to reconnect, anyway (similar to how we do it in HAKit). When this happens, we ask the frontend to
        // reset its WebSocket connection, thus eliminating the wait.
        //
        // It's likely this doesn't apply before iOS 15, but it may improve the reconnect timing there anyhow.

        reconnectBackgroundTimer = Timer.scheduledTimer(
            withTimeInterval: 5.0,
            repeats: true,
            block: { [weak self] timer in
                if let self = self, Current.date().timeIntervalSince(timer.fireDate) > 30.0 {
                    self.sendExternalBus(message: .init(command: "restart"))
                }

                if UIApplication.shared.applicationState == .active {
                    timer.invalidate()
                }
            }
        )
    }
}

extension String {
    func matchingStrings(regex: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return [] }
        let nsString = self as NSString
        let results = regex.matches(in: self, options: [], range: NSRange(location: 0, length: nsString.length))
        return results.map { result in
            (0 ..< result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
    }
}

extension WebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let messageBody = message.body as? [String: Any] else {
            Current.Log.error("received message for \(message.name) but of type: \(type(of: message.body))")
            return
        }

        Current.Log.verbose("message \(message.body)".replacingOccurrences(of: "\n", with: " "))

        switch message.name {
        case "externalBus":
            handleExternalMessage(messageBody)
        case "updateThemeColors":
            handleThemeUpdate(messageBody)
        case "getExternalAuth":
            guard let callbackName = messageBody["callback"] else { return }

            let force = messageBody["force"] as? Bool ?? false

            Current.Log.verbose("getExternalAuth called, forced: \(force)")

            firstly {
                Current.api(for: server).tokenManager.authDictionaryForWebView(forceRefresh: force)
            }.done { dictionary in
                let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: [])
                if let jsonString = String(data: jsonData!, encoding: .utf8) {
                    // Current.Log.verbose("Responding to getExternalAuth with: \(callbackName)(true, \(jsonString))")
                    let script = "\(callbackName)(true, \(jsonString))"
                    self.webView.evaluateJavaScript(script, completionHandler: { result, error in
                        if let error = error {
                            Current.Log.error("Failed to trigger getExternalAuth callback: \(error)")
                        }

                        Current.Log.verbose("Success on getExternalAuth callback: \(String(describing: result))")
                    })
                }
            }.catch { error in
                self.webView.evaluateJavaScript("\(callbackName)(false, 'Token unavailable')")
                Current.Log.error("Failed to authenticate webview: \(error)")
            }
        case "revokeExternalAuth":
            guard let callbackName = messageBody["callback"] else { return }

            Current.Log.warning("Revoking access token")

            firstly {
                Current.api(for: server).tokenManager.revokeToken()
            }.done { [server] _ in
                Current.servers.remove(identifier: server.identifier)

                let script = "\(callbackName)(true)"

                Current.Log.verbose("Running revoke external auth callback \(script)")

                self.webView.evaluateJavaScript(script, completionHandler: { _, error in
                    Current.onboardingObservation.needed(.logout)

                    if let error = error {
                        Current.Log.error("Failed calling sign out callback: \(error)")
                    }

                    Current.Log.verbose("Successfully informed web client of log out.")
                })
            }.catch { error in
                Current.Log.error("Failed to revoke token: \(error)")
            }
        case "logError":
            Current.Log.error("WebView error: \(messageBody.description.replacingOccurrences(of: "\n", with: " "))")
        default:
            Current.Log.error("unknown message: \(message.name)")
        }
    }

    func handleThemeUpdate(_ messageBody: [String: Any]) {
        ThemeColors.updateCache(with: messageBody, for: traitCollection)
        styleUI()
    }

    func handleHaptic(_ hapticType: String) {
        Current.Log.verbose("Handle haptic type \(hapticType)")
        switch hapticType {
        case "success":
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "error", "failure":
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case "warning":
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case "light":
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case "medium":
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case "heavy":
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case "selection":
            UISelectionFeedbackGenerator().selectionChanged()
        default:
            Current.Log.verbose("Unknown haptic type \(hapticType)")
        }
    }

    func handleExternalMessage(_ dictionary: [String: Any]) {
        guard let incomingMessage = WebSocketMessage(dictionary) else {
            Current.Log.error("Received invalid external message \(dictionary)")
            return
        }

        var response: Guarantee<WebSocketMessage>?

        switch incomingMessage.MessageType {
        case "config/get":
            response = Guarantee { seal in
                DispatchQueue.global(qos: .userInitiated).async {
                    seal(WebSocketMessage(
                        id: incomingMessage.ID!,
                        type: "result",
                        result: [
                            "hasSettingsScreen": !Current.isCatalyst,
                            "canWriteTag": Current.tags.isNFCAvailable,
                            "canCommissionMatter": Current.matter.isAvailable,
                        ]
                    ))
                }
            }
        case "config_screen/show":
            showSettingsViewController()
        case "haptic":
            guard let hapticType = incomingMessage.Payload?["hapticType"] as? String else {
                Current.Log.error("Received haptic via bus but hapticType was not string! \(incomingMessage)")
                return
            }
            handleHaptic(hapticType)
        case "connection-status":
            guard let connEvt = incomingMessage.Payload?["event"] as? String else {
                Current.Log.error("Received connection-status via bus but event was not string! \(incomingMessage)")
                return
            }
            // Possible values: connected, disconnected, auth-invalid
            UIView.animate(withDuration: 1.0, delay: 0, options: .curveEaseInOut, animations: {
                self.settingsButton.alpha = connEvt == "connected" ? 0.0 : 1.0
            }, completion: nil)
        case "tag/read":
            response = Current.tags.readNFC().map { tag in
                WebSocketMessage(id: incomingMessage.ID!, type: "result", result: ["success": true, "tag": tag])
            }.recover { _ in
                .value(WebSocketMessage(id: incomingMessage.ID!, type: "result", result: ["success": false]))
            }
        case "tag/write":
            let (promise, seal) = Guarantee<Bool>.pending()
            response = promise.map { success in
                WebSocketMessage(id: incomingMessage.ID!, type: "result", result: ["success": success])
            }

            firstly { () throws -> Promise<(tag: String, name: String?)> in
                if let tag = incomingMessage.Payload?["tag"] as? String, tag.isEmpty == false {
                    return .value((tag: tag, name: incomingMessage.Payload?["name"] as? String))
                } else {
                    throw HomeAssistantAPI.APIError.invalidResponse
                }
            }.then { tagInfo in
                Current.tags.writeNFC(value: tagInfo.tag)
            }.done { _ in
                Current.Log.info("wrote tag via external bus")
                seal(true)
            }.catch { error in
                Current.Log.error("couldn't write tag via external bus: \(error)")
                seal(false)
            }
        case "theme-update":
            webView.evaluateJavaScript("notifyThemeColors()", completionHandler: nil)
        case "matter/commission":
            Current.matter.commission(server).done {
                Current.Log.info("commission call completed")
            }.catch { error in
                // we don't show a user-visible error because even a successful operation will return 'cancelled'
                // but the errors aren't public, so we can't compare -- the apple ui shows errors visually though
                Current.Log.error(error)
            }
        default:
            Current.Log.error("unknown: \(incomingMessage.MessageType)")
            return
        }

        response?.then { [self] outgoing in
            sendExternalBus(message: outgoing)
        }.cauterize()
    }

    @discardableResult
    private func sendExternalBus(message: WebSocketMessage) -> Promise<Void> {
        Promise<Void> { seal in
            DispatchQueue.main.async { [self] in
                do {
                    let encodedMsg = try JSONEncoder().encode(message)
                    let jsonString = String(decoding: encodedMsg, as: UTF8.self)
                    let script = "window.externalBus(\(jsonString))"
                    Current.Log.verbose("sending \(jsonString)")
                    webView.evaluateJavaScript(script, completionHandler: { _, error in
                        if let error = error {
                            Current.Log.error("failed to fire message to externalBus: \(error)")
                        }
                        seal.resolve(error)
                    })
                } catch {
                    Current.Log.error("failed to send \(message): \(error)")
                    seal.reject(error)
                }
            }
        }
    }
}

extension WebViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y > scrollView.contentSize.height - scrollView.bounds.height {
            scrollView.contentOffset.y = scrollView.contentSize.height - scrollView.bounds.height
        }
    }
}

extension ConnectionInfo {
    mutating func webviewURLComponents() -> URLComponents? {
        if Current.appConfiguration == .FastlaneSnapshot, prefs.object(forKey: "useDemo") != nil {
            return URLComponents(string: "https://companion.home-assistant.io/app/ios/demo")!
        }
        guard var components = URLComponents(url: activeURL(), resolvingAgainstBaseURL: true) else {
            return nil
        }

        let queryItem = URLQueryItem(name: "external_auth", value: "1")
        components.queryItems = [queryItem]

        return components
    }

    mutating func webviewURL() -> URL? {
        webviewURLComponents()?.url
    }

    mutating func webviewURL(from raw: String) -> URL? {
        guard let baseURLComponents = webviewURLComponents(), let baseURL = baseURLComponents.url else {
            return nil
        }

        if raw.starts(with: "/") {
            if let rawComponents = URLComponents(string: raw) {
                var components = baseURLComponents
                components.path.append(rawComponents.path)
                components.fragment = rawComponents.fragment

                if let items = rawComponents.queryItems {
                    var queryItems = components.queryItems ?? []
                    queryItems.append(contentsOf: items)
                    components.queryItems = queryItems
                }

                return components.url
            } else {
                return baseURL.appendingPathComponent(raw)
            }
        } else if let url = URL(string: raw), url.baseIsEqual(to: baseURL) {
            return url
        } else {
            return nil
        }
    }
}
