//
//  WebViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/10/17.
//  Copyright © 2017 Robbie Trencheny. All rights reserved.
//

import UIKit
import Alamofire
import WebKit
import KeychainAccess
import PromiseKit
import SwiftMessages
import Shared
import AVFoundation
import AVKit
import CoreLocation

// swiftlint:disable:next type_body_length
class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UIViewControllerRestoration {

    var webView: WKWebView!

    var urlObserver: NSKeyValueObservation?

    let refreshControl = UIRefreshControl()

    // var remotePlayer = RemoteMediaPlayer()

    var keepAliveTimer: Timer?
    private var initialURL: URL?

    static func viewController(
        withRestorationIdentifierPath identifierComponents: [String],
        coder: NSCoder
    ) -> UIViewController? {
        if #available(iOS 13, *) {
            return nil
        } else {
            let webViewController = WebViewController(restorationActivity: nil)
            // although the system is also going to call through this restoration method, it's going to do it _too late_
            webViewController.decodeRestorableState(with: coder)
            return webViewController
        }
    }

    let settingsButton: UIButton! = {
        let button = UIButton()
        button.setImage(MaterialDesignIcons.cogIcon.image(ofSize: CGSize(width: 36, height: 36), color: .white),
                        for: .normal)
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
    }

    override func encodeRestorableState(with coder: NSCoder) {
        if #available(iOS 13, *) {

        } else {
            super.encodeRestorableState(with: coder)
            coder.encode(webView.url as NSURL?, forKey: RestorableStateKey.lastURL.rawValue)
        }
    }

    override func decodeRestorableState(with coder: NSCoder) {
        if #available(iOS 13, *) {

        } else {
            guard !isViewLoaded else {
                // this is state decoding late in the cycle, not our initial one; ignore.
                return
            }

            initialURL = coder.decodeObject(of: NSURL.self, forKey: RestorableStateKey.lastURL.rawValue) as URL?
            super.decodeRestorableState(with: coder)
        }
    }

    // swiftlint:disable:next function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 13, *) {

        } else {
            restorationClass = Self.self
            restorationIdentifier = String(describing: Self.self)
        }

        self.becomeFirstResponder()

        for name: Notification.Name in [
            SettingsStore.connectionInfoDidChange,
            HomeAssistantAPI.didConnectNotification
        ] {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(connectionInfoDidChange),
                name: name,
                object: nil
            )
        }

        let statusBarView = UIView()
        statusBarView.tag = 111

        view.addSubview(statusBarView)

        statusBarView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        statusBarView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        statusBarView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        statusBarView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor).isActive = true

        statusBarView.translatesAutoresizingMaskIntoConstraints = false

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "getExternalAuth")
        userContentController.add(self, name: "revokeExternalAuth")
        userContentController.add(self, name: "externalBus")
        userContentController.add(self, name: "updateThemeColors")
        userContentController.add(self, name: "currentUser")
        userContentController.add(self, name: "mediaPlayerCommand")

        if let webhookID = Current.settingsStore.connectionInfo?.webhookID {
            let webhookGlobal = "window.webhookID = '\(webhookID)';"
            userContentController.addUserScript(WKUserScript(source: webhookGlobal, injectionTime: .atDocumentStart,
                                                             forMainFrameOnly: false))
        }

        guard let wsBridgeJSPath = Bundle.main.path(forResource: "WebSocketBridge", ofType: "js"),
            let wsBridgeJS = try? String(contentsOfFile: wsBridgeJSPath) else {
                fatalError("Couldn't load WebSocketBridge.js for injection to WKWebView!")
        }

        userContentController.addUserScript(WKUserScript(source: wsBridgeJS, injectionTime: .atDocumentEnd,
                                                         forMainFrameOnly: false))

        if Current.appConfiguration == .FastlaneSnapshot {
            let hideDemoCardScript = WKUserScript(source: "localStorage.setItem('hide_demo_card', '1');",
                                                  injectionTime: .atDocumentStart,
                                                  forMainFrameOnly: false)
            userContentController.addUserScript(hideDemoCardScript)

            if let langCode = Locale.current.languageCode {
                // swiftlint:disable:next line_length
                let setLanguageScript = WKUserScript(source: "localStorage.setItem('selectedLanguage', '\"\(langCode)\"');",
                                                     injectionTime: .atDocumentStart,
                                                     forMainFrameOnly: false)
                userContentController.addUserScript(setLanguageScript)
            }

            SettingsViewController.showMapContentExtension()
        }

        config.userContentController = userContentController
        // "Mobile/BUILD_NUMBER" is what CodeMirror sniffs for to decide iOS or not; other things likely look for Safari
        config.applicationNameForUserAgent = HomeAssistantAPI.userAgent + " Mobile/HomeAssistant, like Safari"

        self.webView = WKWebView(frame: self.view!.frame, configuration: config)
        self.webView.isOpaque = false
        self.view!.addSubview(webView)

        urlObserver = self.webView.observe(\.url) { [weak self] (webView, _) in
            guard let self = self else { return }

            guard let currentURL = webView.url?.absoluteString.replacingOccurrences(of: "?external_auth=1", with: ""),
                  let cleanURL = URL(string: currentURL), let scheme = cleanURL.scheme
            else {
                return
            }

            guard ["http", "https"].contains(scheme) else {
                Current.Log.warning("Was going to provide invalid URL to NSUserActivity! \(currentURL)")
                return
            }

            self.userActivity?.webpageURL = cleanURL
            self.userActivity?.userInfo = [RestorableStateKey.lastURL.rawValue: cleanURL]
            self.userActivity?.becomeCurrent()
        }

        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self

        self.webView.translatesAutoresizingMaskIntoConstraints = false

        self.webView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        self.webView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        self.webView.topAnchor.constraint(equalTo: statusBarView.bottomAnchor).isActive = true
        self.webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true

        self.webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        if !Current.isCatalyst {
            // refreshing is handled by menu/keyboard shortcuts
            refreshControl.addTarget(self, action: #selector(self.pullToRefresh(_:)), for: .valueChanged)
            webView.scrollView.addSubview(refreshControl)
            webView.scrollView.bounces = true
        }

        self.settingsButton.addTarget(self, action: #selector(self.openSettingsView(_:)), for: .touchDown)

        self.view.addSubview(self.settingsButton)

        self.view.bottomAnchor.constraint(equalTo: self.settingsButton.bottomAnchor, constant: 16.0).isActive = true
        self.view.rightAnchor.constraint(equalTo: self.settingsButton.rightAnchor, constant: 16.0).isActive = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateWebViewSettings),
            name: SettingsStore.webViewRelatedSettingDidChange,
            object: nil
        )
        updateWebViewSettings()

        styleUI()
    }

    public func showSettingsViewController() {
        if #available(iOS 13, *), Current.sceneManager.supportsMultipleScenes, Current.isCatalyst {
            Current.sceneManager.activateAnyScene(for: .settings)
        } else {
            let settingsView = SettingsViewController()
            settingsView.hidesBottomBarWhenPushed = true
            let navController = UINavigationController(rootViewController: settingsView)
            self.navigationController?.present(navController, animated: true, completion: nil)
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

        self.navigationController?.setNavigationBarHidden(true, animated: false)

        // if we aren't showing a url or it's an incorrect url, update it -- otherwise, leave it alone
        if let connectionInfo = Current.settingsStore.connectionInfo,
            let webviewURL = connectionInfo.webviewURL(),
            webView.url == nil || webView.url?.baseIsEqual(to: webviewURL) == false {
            let myRequest: URLRequest

            if Current.settingsStore.restoreLastURL,
                let initialURL = initialURL, initialURL.baseIsEqual(to: webviewURL) {
                Current.Log.info("restoring initial url")
                myRequest = URLRequest(url: initialURL)
            } else {
                Current.Log.info("loading default url")
                myRequest = URLRequest(url: webviewURL)
            }

            self.webView.load(myRequest)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.userActivity?.resignCurrent()
    }

    init(restorationActivity: NSUserActivity?) {
        super.init(nibName: nil, bundle: nil)

        userActivity = with(NSUserActivity(activityType: "\(Constants.BundleID).frontend")) {
            $0.isEligibleForHandoff = true
        }

        if let url = restorationActivity?.userInfo?[RestorableStateKey.lastURL.rawValue] as? URL {
            initialURL = url
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.urlObserver = nil
    }

    private func styleUI() {
        precondition(isViewLoaded && webView != nil)

        let cachedColors = ThemeColors.cachedThemeColors(for: traitCollection)

        self.webView?.backgroundColor = cachedColors[.primaryBackgroundColor]
        self.webView?.scrollView.backgroundColor = cachedColors[.primaryBackgroundColor]

        if let statusBarView = self.view.viewWithTag(111) {
            statusBarView.backgroundColor = cachedColors[.appHeaderBackgroundColor]
        }

        self.refreshControl.tintColor = cachedColors[.primaryColor]

        let headerBackgroundIsLight = cachedColors[.appHeaderBackgroundColor].isLight
        if #available(iOS 13, *) {
            self.underlyingPreferredStatusBarStyle = headerBackgroundIsLight ? .darkContent : .lightContent
        } else {
            self.underlyingPreferredStatusBarStyle = headerBackgroundIsLight ? .default : .lightContent
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
        webView.load(URLRequest(url: url))
    }

    private var lastNavigationWasServerError = false

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            openURLInBrowser(navigationAction.request.url!, self)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.refreshControl.endRefreshing()
        if let err = error as? URLError {
            if err.code != .cancelled {
                Current.Log.error("Failure during nav: \(err)")
            }

            if !error.isCancelled {
                openSettingsWithError(error: error)
            }
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.refreshControl.endRefreshing()
        if let err = error as? URLError {
            if err.code != .cancelled {
                Current.Log.error("Failure during content load: \(error)")
            }

            if !error.isCancelled {
                openSettingsWithError(error: error)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.refreshControl.endRefreshing()

        // in case the view appears again, don't reload
        initialURL = nil
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

            if let connectionInfo = Current.settingsStore.connectionInfo,
                let webviewURL = connectionInfo.webviewURL() {
                decisionHandler(.cancel)
                webView.load(URLRequest(url: webviewURL))
            } else {
                // we don't have anything we can do about this
                decisionHandler(.allow)
            }
        }
    }

    // WKUIDelegate
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let style: UIAlertController.Style = {
            switch webView.traitCollection.userInterfaceIdiom {
            case .carPlay, .phone, .tv:
                return .actionSheet
            #if compiler(>=5.3)
            case .mac:
                return.alert
            #endif
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

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)

        alertController.addTextField { (textField) in
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

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
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

    @objc private func connectionInfoDidChange() {
        DispatchQueue.main.async { [self] in
            loadActiveURLIfNeeded()
        }
    }

    @objc private func loadActiveURLIfNeeded() {
        guard let desiredURL = Current.settingsStore.connectionInfo?.webviewURL() else {
            return
        }

        guard webView.url == nil || webView.url?.baseIsEqual(to: desiredURL) == false else {
            Current.Log.info("not changing webview url - we're okay with what we have")
            // we also tell the webview -- maybe it failed to connect itself? -- to refresh if needed
            webView.evaluateJavaScript("checkForMissingHassConnectionAndReload()", completionHandler: nil)
            return
        }

        Current.Log.verbose("Changing webview to current active URL!")
        webView.load(URLRequest(url: desiredURL))
    }

    @objc private func refresh() {
        // called via menu/keyboard shortcut too
        if let webviewURL = Current.settingsStore.connectionInfo?.webviewURL() {
            if webView.url?.baseIsEqual(to: webviewURL) == true && !lastNavigationWasServerError {
                webView.reload()
            } else {
                webView.load(URLRequest(url: webviewURL))
            }
        }
    }

    @objc private func updateSensors() {
        // called via menu/keyboard shortcut too
        Current.backgroundTask(withName: "manual-location-update") { remaining in
            Current.api.then { api -> Promise<HomeAssistantAPI> in
                guard #available(iOS 14, *) else {
                    return .value(api)
                }

                return Promise { seal in
                    let locationManager = CLLocationManager()

                    guard locationManager.accuracyAuthorization != .fullAccuracy else {
                        seal.fulfill(api)
                        return
                    }

                    Current.Log.info("requesting full accuracy for manual update")
                    locationManager.requestTemporaryFullAccuracyAuthorization(
                        withPurposeKey: "TemporaryFullAccuracyReasonManualUpdate"
                    ) { error in
                        Current.Log.info("got temporary full accuracy result: \(String(describing: error))")

                        withExtendedLifetime(locationManager) {
                            seal.fulfill(api)
                        }
                    }
                }
            }.then { api -> Promise<Void> in
                func updateWithoutLocation() -> Promise<Void> {
                    api.UpdateSensors(trigger: .Manual)
                }

                if Current.settingsStore.isLocationEnabled(for: UIApplication.shared.applicationState) {
                    return api.GetAndSendLocation(trigger: .Manual, maximumBackgroundTime: remaining)
                        .recover { error -> Promise<Void> in
                            if error is CLError {
                                Current.Log.info("couldn't get location, sending remaining sensor data")
                                return updateWithoutLocation()
                            } else {
                                throw error
                            }
                    }
                } else {
                    return updateWithoutLocation()
                }
            }
        }.catch { error in
            self.showSwiftMessageError((error as NSError).localizedDescription)
        }
    }

    @objc func pullToRefresh(_ sender: UIRefreshControl) {
        refresh()
        updateSensors()
    }

    func show(alert: ServerAlert) {
        Current.Log.info("showing alert \(alert)")

        var config = SwiftMessages.Config()

        config.presentationContext = .viewController(self)
        config.duration = .forever
        config.presentationStyle = .bottom
        config.dimMode = .gray(interactive: true)
        config.dimModeAccessibilityLabel = L10n.cancelLabel
        config.eventListeners.append({ event in
            if event == .didHide {
                Current.serverAlerter.markHandled(alert: alert)
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

    func showSwiftMessageError(_ body: String, duration: SwiftMessages.Duration = .automatic) {
        var config = SwiftMessages.Config()

        config.presentationContext = .window(windowLevel: .statusBar)
        config.duration = duration

        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(.error)
        view.configureContent(body: body)

        SwiftMessages.show(config: config, view: view)

    }

    func openSettingsWithError(error: Error) {
        self.showSwiftMessageError(error.localizedDescription, duration: SwiftMessages.Duration.seconds(seconds: 10))
        self.showSwiftMessageError(error.localizedDescription)

//        let alert = UIAlertController(title: L10n.errorLabel, message: error.localizedDescription,
//                                      preferredStyle: .alert)
//        alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default, handler: nil))
//        self.navigationController?.present(alert, animated: true, completion: nil)
//        alert.popoverPresentationController?.sourceView = self.webView

        /* let settingsView = SettingsViewController()
        settingsView.showErrorConnectingMessage = true
        settingsView.showErrorConnectingMessageError = error
        settingsView.doneButton = true
        settingsView.delegate = self
        let navController = UINavigationController(rootViewController: settingsView)
        self.navigationController?.present(navController, animated: true, completion: nil) */
    }

    @objc func openSettingsView(_ sender: UIButton) {
        self.showSettingsViewController()
    }

    private var underlyingPreferredStatusBarStyle: UIStatusBarStyle = .lightContent
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return underlyingPreferredStatusBarStyle
    }

    @objc private func updateWebViewSettings() {
        // iOS 14's `pageZoom` property is almost this, but not quite - it breaks the layout as well
        // This is quasi-private API that has existed since pre-iOS 10, but the implementation
        // changed in iOS 12 to be like the +/- zoom buttons in Safari, which scale content without
        // resizing the scrolling viewport.
        let viewScale = Current.settingsStore.pageZoom.viewScaleValue
        Current.Log.info("setting view scale to \(viewScale)")
        webView.setValue(viewScale, forKey: "viewScale")
    }
}

extension String {
    func matchingStrings(regex: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return [] }
        let nsString = self as NSString
        let results = regex.matches(in: self, options: [], range: NSRange(location: 0, length: nsString.length))
        return results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
    }
}

extension WebViewController: WKScriptMessageHandler {
    // swiftlint:disable:next function_body_length
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let messageBody = message.body as? [String: Any] else { return }

        // Current.Log.verbose("Received script message \(message.name) \(message.body)")

        /* if message.name == "mediaPlayerCommand" {
            guard let cmdStr = messageBody["type"] as? String, let cmd = RemotePlayerCommands(rawValue: cmdStr) else {
                Current.Log.error("No command type in payload! \(messageBody)")
                return
            }
            self.remotePlayer.handleCommand(cmd, messageBody["data"])
        } else */ if message.name == "externalBus" {
            self.handleExternalMessage(messageBody)
        } else if message.name == "currentUser", let user = AuthenticatedUser(messageBody) {
            Current.settingsStore.authenticatedUser = user
        } else if message.name == "updateThemeColors" {
            self.handleThemeUpdate(messageBody)
        } else if message.name == "getExternalAuth", let callbackName = messageBody["callback"] {
            let force = messageBody["force"] as? Bool ?? false
            if let tokenManager = Current.tokenManager {
                Current.Log.verbose("getExternalAuth called, forced: \(force)")
                tokenManager.authDictionaryForWebView(forceRefresh: force).done { dictionary in
                    let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: [])
                    if let jsonString = String(data: jsonData!, encoding: .utf8) {
                        // swiftlint:disable:next line_length
                        // Current.Log.verbose("Responding to getExternalAuth with: \(callbackName)(true, \(jsonString))")
                        let script = "\(callbackName)(true, \(jsonString))"
                        self.webView.evaluateJavaScript(script, completionHandler: { (result, error) in
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
            } else {
                self.webView.evaluateJavaScript("\(callbackName)(false, 'Token unavailable')")
                Current.Log.error("Failed to authenticate webview. Token Unavailable")
            }
        } else if message.name == "revokeExternalAuth", let callbackName = messageBody["callback"],
            let tokenManager = Current.tokenManager {

            Current.Log.warning("Revoking access token")

            tokenManager.revokeToken().done { _ in
                Current.resetAPI()
                Current.tokenManager = nil
                Current.settingsStore.connectionInfo = nil
                Current.settingsStore.tokenInfo = nil
                let script = "\(callbackName)(true)"

                Current.Log.verbose("Running revoke external auth callback \(script)")

                self.webView.evaluateJavaScript(script, completionHandler: { (_, error) in
                    Current.onboardingObservation.needed(.logout)

                    if let error = error {
                        Current.Log.error("Failed calling sign out callback: \(error)")
                    }

                    Current.Log.verbose("Successfully informed web client of log out.")
                })
            }.catch { error in
                Current.Log.error("Failed to revoke token: \(error)")
            }
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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func handleExternalMessage(_ dictionary: [String: Any]) {
        guard let incomingMessage = WebSocketMessage(dictionary) else {
            Current.Log.error("Received invalid external message \(dictionary)")
            return
        }

        // Current.Log.verbose("Received external bus message \(incomingMessage)")

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
                            "canWriteTag": Current.tags.isNFCAvailable
                        ]
                    ))
                }
            }
        case "config_screen/show":
            self.showSettingsViewController()
        case "haptic":
            guard let hapticType = incomingMessage.Payload?["hapticType"] as? String else {
                Current.Log.error("Received haptic via bus but hapticType was not string! \(incomingMessage)")
                return
            }
            self.handleHaptic(hapticType)
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
                WebSocketMessage(id: incomingMessage.ID!, type: "result", result: [ "success": true, "tag": tag ])
            }.recover { _ in
                .value(WebSocketMessage(id: incomingMessage.ID!, type: "result", result: [ "success": false ] ))
            }
        case "tag/write":
            let (promise, seal) = Guarantee<Bool>.pending()
            response = promise.map { success in
                WebSocketMessage(id: incomingMessage.ID!, type: "result", result: [ "success": success ])
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
        default:
            Current.Log.error("Received unknown external message \(incomingMessage)")
            return
        }

        response?.done(on: .main) { outgoing in
            // Current.Log.verbose("Sending response to \(outgoing)")

            var encodedMsg: Data?

            do {
                encodedMsg = try JSONEncoder().encode(outgoing)
            } catch let error as NSError {
                Current.Log.error("Unable to encode outgoing message! \(error)")
                return
            }

            guard let jsonString = String(data: encodedMsg!, encoding: .utf8) else {
                Current.Log.error("Could not convert JSON Data to JSON String")
                return
            }

            let script = "window.externalBus(\(jsonString))"
            // Current.Log.verbose("Sending message to externalBus \(script)")
            self.webView.evaluateJavaScript(script, completionHandler: { (_, error) in
                if let error = error {
                    Current.Log.error("Failed to fire message to externalBus: \(error)")
                }

                /* if let result = result {
                    Current.Log.verbose("Success on firing message to externalBus: \(String(describing: result))")
                } else {
                    Current.Log.verbose("Sent message to externalBus")
                } */
            })
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
    func webviewURL() -> URL? {
        if Current.appConfiguration == .FastlaneSnapshot, prefs.object(forKey: "useDemo") != nil {
            return URL(string: "https://companion.home-assistant.io/app/ios/demo")!
        }
        guard var components = URLComponents(url: self.activeURL, resolvingAgainstBaseURL: true) else {
            return nil
        }

        if Current.settingsStore.tokenInfo != nil {
            let queryItem = URLQueryItem(name: "external_auth", value: "1")
            components.queryItems = [queryItem]
        }

        return try? components.asURL()
    }

    func webviewURL(from raw: String) -> URL? {
        guard let baseURL = webviewURL() else {
            return nil
        }

        if raw.starts(with: "/") {
            return baseURL.appendingPathComponent(raw)
        } else if let url = URL(string: raw), url.baseIsEqual(to: baseURL) {
            return url
        } else {
            return nil
        }
    }
// swiftlint:disable:next file_length
}
