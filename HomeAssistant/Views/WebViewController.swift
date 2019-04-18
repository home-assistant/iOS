//
//  WebViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/10/17.
//  Copyright © 2017 Robbie Trencheny. All rights reserved.
//

import UIKit
import WebKit
import KeychainAccess
import PromiseKit
import Shared
import arek

// swiftlint:disable:next type_body_length
class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, ConnectionInfoChangedDelegate {

    var webView: FullScreenWKWebView!
    var shouldHideToolbar: Bool {
        if Current.appConfiguration != .FastlaneSnapshot {
            return prefs.bool(forKey: "autohideToolbar")
        }
        return false
    }
    var waitingToHideToolbar: Bool = false

    // swiftlint:disable:next function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()
        self.becomeFirstResponder()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(WebViewController.loadActiveURLIfNeeded),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)

        let statusBarView: UIView = UIView(frame: UIApplication.shared.statusBarFrame)
        statusBarView.tag = 111

        view.addSubview(statusBarView)

        self.styleUI()

        statusBarView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        statusBarView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        statusBarView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        statusBarView.bottomAnchor.constraint(equalTo: self.topLayoutGuide.bottomAnchor).isActive = true

        statusBarView.translatesAutoresizingMaskIntoConstraints = false

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "getExternalAuth")
        userContentController.add(self, name: "revokeExternalAuth")
        userContentController.add(self, name: "themesUpdated")
        userContentController.add(self, name: "handleHaptic")

        let themeScriptSource = """
                               const handleThemeUpdate = (event) => {
                                  var payload = event.data || event;
                                  let themeName = payload.default_theme;
                                  if(themeName === "default") {
                                    window.webkit.messageHandlers.themesUpdated.postMessage({
                                      "name": themeName
                                    });
                                  } else {
                                    window.webkit.messageHandlers.themesUpdated.postMessage({
                                      "name": themeName,
                                      "styles": payload.themes[themeName]
                                    });
                                  }
                                }

                                window.hassConnection.then(({ conn }) => {
                                  conn.sendMessagePromise({type: 'frontend/get_themes'}).then(handleThemeUpdate);
                                  conn.subscribeEvents(handleThemeUpdate, "themes_updated");
                                });
                               """

        let themeScript = WKUserScript(source: themeScriptSource, injectionTime: .atDocumentEnd,
                                       forMainFrameOnly: false)
        userContentController.addUserScript(themeScript)

        config.userContentController = userContentController

        self.webView = FullScreenWKWebView(frame: self.view!.frame, configuration: config)
        self.webView.isOpaque = true
        self.webView.scrollView.backgroundColor = UIColor(red: 0.90, green: 0.90, blue: 0.90, alpha: 1.0)
        self.view!.addSubview(webView)

        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        if self.shouldHideToolbar {
            self.webView.scrollView.delegate = self
        }

        self.webView.translatesAutoresizingMaskIntoConstraints = false

        self.webView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        self.webView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        self.webView.topAnchor.constraint(equalTo: statusBarView.bottomAnchor).isActive = true
        self.webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true

        self.webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.webView.scrollView.bounces = false

        CheckPermissionsStatus()

        if let api = HomeAssistantAPI.authenticatedAPI() {
            if let connectionInfo = Current.settingsStore.connectionInfo,
                let webviewURL = connectionInfo.webviewURL() {
                api.Connect().done {_ in
                    if Current.settingsStore.notificationsEnabled {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    Current.Log.verbose("Connected!")
                    self.webView.load(URLRequest(url: webviewURL))
                    return
                }.catch {err -> Void in
                    Current.Log.error("Error on connect!!! \(err)")
                    self.openSettingsWithError(error: err)
                }
            }
        } else {
            self.showSettingsViewController()
        }
    }

    public func showSettingsViewController() {
        let settingsView = SettingsViewController()
        settingsView.doneButton = true
        settingsView.delegate = self
        let navController = UINavigationController(rootViewController: settingsView)
        self.present(navController, animated: true, completion: nil)
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

        if let connectionInfo = Current.settingsStore.connectionInfo,
            let webviewURL = connectionInfo.webviewURL() {
            let myRequest = URLRequest(url: webviewURL)
            self.webView.load(myRequest)
        }
    }

    func styleUI(_ icons: UIColor? = nil, _ header: UIColor? = nil, _ toolbar: UIColor? = nil) {
        // Default blue color
        var toolbarIconColor = UIColor(red: 0.01, green: 0.66, blue: 0.96, alpha: 1.0)
        if let iconColor = icons {
            toolbarIconColor = iconColor
        } else if let storedThemeColor = prefs.string(forKey: "themeColor") {
            toolbarIconColor = UIColor.init(hex: storedThemeColor)
        }

        var barItems: [UIBarButtonItem] = []

        if let statusBarView = self.view.viewWithTag(111) {
            var headerColor = toolbarIconColor
            if let header = header {
                headerColor = header
            }
            statusBarView.backgroundColor = headerColor
        }

        if Current.settingsStore.locationEnabled {

            let uploadIcon = UIImage.iconForIdentifier("mdi:upload",
                                                       iconWidth: 30, iconHeight: 30,
                                                       color: toolbarIconColor)

            barItems.append(UIBarButtonItem(image: uploadIcon,
                                            style: .plain,
                                            target: self,
                                            action: #selector(sendCurrentLocation(_:))
                )
            )

            // WARNING: If you re-enable, check this file for presence of FIXMEs to fully re-enable
//            let mapIcon = UIImage.iconForIdentifier("mdi:map", iconWidth: 30, iconHeight: 30, color: toolbarIconColor)
//
//            barItems.append(UIBarButtonItem(image: mapIcon,
//                                            style: .plain,
//                                            target: self,
//                                            action: #selector(openMapView(_:))))
        }

        barItems.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil))

        barItems.append(UIBarButtonItem(barButtonSystemItem: .refresh, target: self,
                                        action: #selector(refreshWebView(_:forEvent:))))

        let settingsIcon = UIImage.iconForIdentifier("mdi:settings", iconWidth: 30, iconHeight: 30,
                                                     color: toolbarIconColor)

        barItems.append(UIBarButtonItem(image: settingsIcon,
                                        style: .plain,
                                        target: self,
                                        action: #selector(openSettingsView(_:))))

        self.setToolbarItems(barItems, animated: false)
        self.navigationController?.toolbar.tintColor = toolbarIconColor
        self.navigationController?.toolbar.barTintColor = toolbar
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            openURLInBrowser(urlToOpen: navigationAction.request.url!)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
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
        if let err = error as? URLError {
            if err.code != .cancelled {
                Current.Log.error("Failure during content load: \(error)")
            }

            if !error.isCancelled {
                openSettingsWithError(error: error)
            }
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        let stop = UIBarButtonItem(barButtonSystemItem: .stop, target: self,
                                   action: #selector(self.refreshWebView(_:forEvent:)))
        var removeAt = 2
        if self.toolbarItems?.count == 3 {
            removeAt = 1
        } else if self.toolbarItems?.count == 4 {
            // FIXME: Change this back to 5 if map gets re-added
            removeAt = 2
        }
        var items = self.toolbarItems
        items?.remove(at: removeAt)
        items?.insert(stop, at: removeAt)
        self.setToolbarItems(items, animated: true)
    }

    // for basic auth, fixes #95
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping(URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        let authMethod = challenge.protectionSpace.authenticationMethod

        guard authMethod == NSURLAuthenticationMethodDefault ||
              authMethod == NSURLAuthenticationMethodHTTPBasic ||
              authMethod == NSURLAuthenticationMethodHTTPDigest else {
            Current.Log.verbose("Not handling auth method \(authMethod)")
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if let connectionInfo = Current.settingsStore.connectionInfo,
            let basicAuthCreds = connectionInfo.basicAuthCredentials {
            Current.Log.verbose("WKWebView hit basic auth challenge")
            completionHandler(.useCredential, URLCredential(user: basicAuthCreds.username,
                                                            password: basicAuthCreds.password,
                                                            persistence: .synchronizable))
            return
        }

        let space = challenge.protectionSpace

        let alert = UIAlertController(title: "\(space.`protocol`!)://\(space.host):\(space.port)",
            message: space.realm, preferredStyle: .alert)

        alert.addTextField {
            $0.placeholder = L10n.usernameLabel
        }

        alert.addTextField {
            $0.placeholder = L10n.Settings.ConnectionSection.BasicAuth.Password.title
            $0.isSecureTextEntry = true
        }

        alert.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel) { _ in
            completionHandler(.cancelAuthenticationChallenge, nil)
        })

        alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default) { _ in
            let textFields = alert.textFields!
            let credential = URLCredential(user: textFields[0].text!,
                                           password: textFields[1].text!,
                                           persistence: .forSession)
            completionHandler(.useCredential, credential)
        })

        present(alert, animated: true, completion: nil)

        alert.popoverPresentationController?.barButtonItem = self.toolbarItems?.last

    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        var removeAt = 2
        if self.toolbarItems?.count == 3 {
            removeAt = 1
        } else if self.toolbarItems?.count == 5 {
            removeAt = 3
        }
        let refresh = UIBarButtonItem(barButtonSystemItem: .refresh, target: self,
                                      action: #selector(self.refreshWebView(_:forEvent:)))
        var items = self.toolbarItems
        items?.remove(at: removeAt)
        items?.insert(refresh, at: removeAt)
        self.setToolbarItems(items, animated: true)

        if self.shouldHideToolbar {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self.navigationController?.setToolbarHidden(true, animated: true)
            }
        }
    }

    // WKUIDelegate
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)

        alertController.addAction(UIAlertAction(title: L10n.Alerts.Confirm.ok, style: .default, handler: { _ in
            completionHandler(true)
        }))

        alertController.addAction(UIAlertAction(title: L10n.Alerts.Confirm.cancel, style: .cancel, handler: { _ in
            completionHandler(false)
        }))

        self.present(alertController, animated: true, completion: nil)

        alertController.popoverPresentationController?.barButtonItem = self.toolbarItems?.last
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

        self.present(alertController, animated: true, completion: nil)

        alertController.popoverPresentationController?.barButtonItem = self.toolbarItems?.last
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)

        alertController.addAction(UIAlertAction(title: L10n.Alerts.Alert.ok, style: .default, handler: { _ in
            completionHandler()
        }))

        self.present(alertController, animated: true, completion: nil)

        alertController.popoverPresentationController?.barButtonItem = self.toolbarItems?.last
    }

    @objc func loadActiveURLIfNeeded() {
        if HomeAssistantAPI.authenticatedAPI() != nil,
            let connectionInfo = Current.settingsStore.connectionInfo,
            let webviewURL = connectionInfo.webviewURL() {
            if let currentURL = self.webView.url, !currentURL.baseIsEqual(to: webviewURL) {
                Current.Log.verbose("Changing webview to current active URL!")
                let myRequest = URLRequest(url: webviewURL)
                self.webView.load(myRequest)
            }
        }
    }

    @objc func refreshWebView(_ sender: UIBarButtonItem, forEvent event: UIEvent) {
        guard let touch = event.allTouches?.first else {
            Current.Log.warning("Unable to get first touch on reload button!")
            self.webView.reload()
            return
        }

        // touch.tapCount == 0 = long press
        // touch.tapCount == 1 = tap

        let redirectOrReload = {
            if self.webView.isLoading {
                self.webView.stopLoading()
            } else if touch.tapCount == 0,
                let webviewURL = Current.settingsStore.connectionInfo?.webviewURL() {
                self.webView.load(URLRequest(url: webviewURL))
            } else if let webviewURL = Current.settingsStore.connectionInfo?.webviewURL(reloadURL: self.webView.url) {
                self.webView.load(URLRequest(url: webviewURL))
            }
        }

        let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
        let date = Date(timeIntervalSince1970: 0)
        if let typeSet = websiteDataTypes as? Set<String> {
            WKWebsiteDataStore.default().removeData(ofTypes: typeSet, modifiedSince: date,
                                                    completionHandler: redirectOrReload)
        } else {
            redirectOrReload()
        }
    }

    func openSettingsWithError(error: Error) {
        let settingsView = SettingsViewController()
        settingsView.showErrorConnectingMessage = true
        settingsView.showErrorConnectingMessageError = error
        settingsView.doneButton = true
        settingsView.delegate = self
        let navController = UINavigationController(rootViewController: settingsView)
        self.present(navController, animated: true, completion: nil)
    }

    @objc func openSettingsView(_ sender: UIButton) {
        let settingsView = SettingsViewController()
        settingsView.doneButton = true
        settingsView.hidesBottomBarWhenPushed = true
        settingsView.delegate = self

        let navController = UINavigationController(rootViewController: settingsView)
        self.present(navController, animated: true, completion: nil)
    }

    @objc func openMapView(_ sender: UIButton) {
        let devicesMapView = DevicesMapViewController()

        let navController = UINavigationController(rootViewController: devicesMapView)
        self.present(navController, animated: true, completion: nil)
    }

    @objc func sendCurrentLocation(_ sender: UIButton) {
        firstly {
            HomeAssistantAPI.authenticatedAPIPromise
        }.then { api in
            api.GetAndSendLocation(trigger: .Manual)
        }.done {_ in
            Current.Log.verbose("Sending current location via button press")
            let alert = UIAlertController(title: L10n.ManualLocationUpdateNotification.title,
                                          message: L10n.ManualLocationUpdateNotification.message,
                                          preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            alert.popoverPresentationController?.barButtonItem = self.toolbarItems?.first
        }.catch {error in
            let nserror = error as NSError
            let message = L10n.ManualLocationUpdateFailedNotification.message(nserror.localizedDescription)
            let alert = UIAlertController(title: L10n.ManualLocationUpdateFailedNotification.title,
                                          message: message,
                                          preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            alert.popoverPresentationController?.barButtonItem = self.toolbarItems?.first
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    func userReconnected() {
        self.loadActiveURLIfNeeded()
    }

    func parseThemeStyle(_ styleKey: String, _ allStyles: [String: String]) -> UIColor? {
        guard let requestedStyle = allStyles[styleKey] else { return nil }

        if !requestedStyle.hasPrefix("var") {
            return UIColor(hex: requestedStyle)
        }

        // CSS variable like `var(--primary-text-color)` or `var(--primary-text-color, var(--secondary-text-color))`

        let pattern = "var\\(--([a-zA-Z-]+)\\)*"

        let styleKeys: [String] = requestedStyle.matchingStrings(regex: pattern).map { $0[1] }

        for key in styleKeys {
            if let color = self.parseThemeStyle(key, allStyles) {
                return color
            }
        }

        return nil
    }

    // We are willing to become first responder to get shake motion
    override var canBecomeFirstResponder: Bool {
        return true
    }

    // Enable detection of shake motion
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake, let navController = self.navigationController, navController.isToolbarHidden {
            self.navigationController?.setToolbarHidden(false, animated: true)
        }
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
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let messageBody = message.body as? [String: Any] else { return }

        if message.name == "handleHaptic", let hapticType = messageBody["hapticType"] as? String {
            self.handleHaptic(hapticType)
        } else if message.name == "themesUpdated" {
            self.handleThemeUpdate(messageBody)
        } else if message.name == "getExternalAuth", let callbackName = messageBody["callback"] {
            if let tokenManager = Current.tokenManager {
                Current.Log.verbose("getExternalAuth called")
                tokenManager.authDictionaryForWebView.done { dictionary in
                    let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: [])
                    if let jsonString = String(data: jsonData!, encoding: .utf8) {
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
                Current.tokenManager = nil
                Current.settingsStore.connectionInfo = nil
                Current.settingsStore.tokenInfo = nil
                self.showSettingsViewController()
                let script = "\(callbackName)(true)"

                Current.Log.verbose("Running revoke external auth callback \(script)")

                self.webView.evaluateJavaScript(script, completionHandler: { (_, error) in
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
        if let styles = messageBody["styles"] as? [String: String] {
            let iconColor = self.parseThemeStyle("sidebar-icon-color", styles)
            let headerColor = self.parseThemeStyle("primary-color", styles)
            var toolbarColor = self.parseThemeStyle("sidebar-background-color", styles)
            if toolbarColor == nil {
                if let primaryBGC = self.parseThemeStyle("primary-background-color", styles) {
                    toolbarColor = primaryBGC
                } else if let plbc = self.parseThemeStyle("paper-listbox-background-color", styles) {
                    toolbarColor = plbc
                }
            }
            self.styleUI(iconColor, headerColor, toolbarColor)
        } else {
            // Assume default theme
            self.styleUI()
        }
    }

    func handleHaptic(_ hapticType: String) {
        Current.Log.verbose("Handle haptic type \(hapticType)")
        switch hapticType {
        case "success":
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "error":
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case "warning":
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case "light":
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case "medium":
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case "heavy":
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case "selected":
            UISelectionFeedbackGenerator().selectionChanged()
        default:
            Current.Log.verbose("Unknown haptic type \(hapticType)")
        }
    }
}

extension WebViewController: UIScrollViewDelegate {
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        Current.Log.verbose("End dragging \(self.waitingToHideToolbar)")
        if velocity.y>0 {
            self.waitingToHideToolbar = false
            self.navigationController?.setToolbarHidden(true, animated: true)
        } else {
            self.navigationController?.setToolbarHidden(false, animated: true)
            self.waitingToHideToolbar = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if self.waitingToHideToolbar {
                    self.navigationController?.setToolbarHidden(true, animated: true)
                }
            }
        }
    }
}

extension ConnectionInfo {
    func webviewURL(reloadURL: URL? = nil) -> URL? {
        var baseURL = self.activeURL
        if let reloadURL = reloadURL {
            baseURL = reloadURL
        }

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        if Current.settingsStore.tokenInfo != nil {
            let queryItem = URLQueryItem(name: "external_auth", value: "1")
            components.queryItems = [queryItem]
        }

        return try? components.asURL()
    }
}

class FullScreenWKWebView: WKWebView {
    override var safeAreaInsets: UIEdgeInsets {
        return .zero
    }
// swiftlint:disable:next file_length
}
