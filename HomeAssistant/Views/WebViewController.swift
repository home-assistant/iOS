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

    var webView: WKWebView!

    // swiftlint:disable:next function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(WebViewController.loadActiveURLIfNeeded),
                                               name: NSNotification.Name.UIApplicationDidBecomeActive,
                                               object: nil)
        let statusBarView: UIView = UIView(frame: .zero)
        statusBarView.tag = 111
        if let themeColor = prefs.string(forKey: "themeColor") {
            statusBarView.backgroundColor = UIColor.init(hex: themeColor)
        } else {
            statusBarView.backgroundColor = UIColor(red: 0.01, green: 0.66, blue: 0.96, alpha: 1.0)
        }
        view.addSubview(statusBarView)

        statusBarView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        statusBarView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        statusBarView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        statusBarView.bottomAnchor.constraint(equalTo: self.topLayoutGuide.bottomAnchor).isActive = true

        statusBarView.translatesAutoresizingMaskIntoConstraints = false

        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "getExternalAuth")
        userContentController.add(self, name: "revokeExternalAuth")
        config.userContentController = userContentController

        self.webView = WKWebView(frame: self.view!.frame, configuration: config)
        self.updateWebViewSettings()
        self.view!.addSubview(webView)

        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self

        self.webView.translatesAutoresizingMaskIntoConstraints = false

        self.webView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        self.webView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        self.webView.topAnchor.constraint(equalTo: self.topLayoutGuide.bottomAnchor).isActive = true
        self.webView.bottomAnchor.constraint(equalTo: self.bottomLayoutGuide.topAnchor).isActive = true
        self.webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.webView.scrollView.bounces = false

        EnsurePermissions()

        if let api = HomeAssistantAPI.authenticatedAPI(),
            let connectionInfo = Current.settingsStore.connectionInfo,
            let webviewURL = connectionInfo.webviewURL {
            api.Connect().done {_ in
                if Current.settingsStore.notificationsEnabled {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("Connected!")
                let myRequest = URLRequest(url: webviewURL)
                self.webView.load(myRequest)
                return
            }.catch {err -> Void in
                print("Error on connect!!!", err)
                self.openSettingsWithError(error: err)
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
        var barItems: [UIBarButtonItem] = []

        var tabBarIconColor = UIColor(red: 0.01, green: 0.66, blue: 0.96, alpha: 1.0)

        if let themeColor = prefs.string(forKey: "themeColor") {
            tabBarIconColor = UIColor.init(hex: themeColor)
            if let statusBarView = self.view.viewWithTag(111) {
                statusBarView.backgroundColor = UIColor.init(hex: themeColor)
            }
        }

        if Current.settingsStore.locationEnabled {

            let uploadIcon = UIImage.iconForIdentifier("mdi:upload",
                                                       iconWidth: 30, iconHeight: 30,
                                                       color: tabBarIconColor)

            barItems.append(UIBarButtonItem(image: uploadIcon,
                                            style: .plain,
                                            target: self,
                                            action: #selector(sendCurrentLocation(_:))
                )
            )

            let mapIcon = UIImage.iconForIdentifier("mdi:map", iconWidth: 30, iconHeight: 30, color: tabBarIconColor)

            barItems.append(UIBarButtonItem(image: mapIcon,
                                            style: .plain,
                                            target: self,
                                            action: #selector(openMapView(_:))))
        }

        barItems.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil))

        barItems.append(UIBarButtonItem(barButtonSystemItem: .refresh, target: self,
                                            action: #selector(refreshWebView(_:))))

        let settingsIcon = UIImage.iconForIdentifier("mdi:settings", iconWidth: 30, iconHeight: 30,
                                                     color: tabBarIconColor)

        barItems.append(UIBarButtonItem(image: settingsIcon,
                                        style: .plain,
                                        target: self,
                                        action: #selector(openSettingsView(_:))))

        self.setToolbarItems(barItems, animated: false)
        self.navigationController?.toolbar.tintColor = tabBarIconColor

        if let connectionInfo = Current.settingsStore.connectionInfo,
            let webviewURL = connectionInfo.webviewURL {
            let myRequest = URLRequest(url: webviewURL)
            self.webView.load(myRequest)
        }
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
        print("Failure during nav", error)
        if !error.isCancelled {
            openSettingsWithError(error: error)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("Failure during content load", error)
        if !error.isCancelled {
            openSettingsWithError(error: error)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        let stop = UIBarButtonItem(barButtonSystemItem: .stop, target: self,
                                   action: #selector(self.refreshWebView(_:)))
        var removeAt = 2
        if self.toolbarItems?.count == 3 {
            removeAt = 1
        } else if self.toolbarItems?.count == 5 {
            removeAt = 3
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
            print("Not handling auth method", authMethod)
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let space = challenge.protectionSpace

        let alert = UIAlertController(title: "\(space.`protocol`!)://\(space.host):\(space.port)",
            message: space.realm, preferredStyle: .alert)

        alert.addTextField {
            $0.placeholder = L10n.usernameLabel
        }

        alert.addTextField {
            $0.placeholder = L10n.Settings.ConnectionSection.ApiPasswordRow.title
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

    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        var removeAt = 2
        if self.toolbarItems?.count == 3 {
            removeAt = 1
        } else if self.toolbarItems?.count == 5 {
            removeAt = 3
        }
        let refresh = UIBarButtonItem(barButtonSystemItem: .refresh, target: self,
                                      action: #selector(self.refreshWebView(_:)))
        var items = self.toolbarItems
        items?.remove(at: removeAt)
        items?.insert(refresh, at: removeAt)
        self.setToolbarItems(items, animated: true)
    }

    @objc func loadActiveURLIfNeeded() {
        if HomeAssistantAPI.authenticatedAPI() != nil,
            let connectionInfo = Current.settingsStore.connectionInfo,
            let webviewURL = connectionInfo.webviewURL {
            if let currentURL = self.webView.url, !currentURL.baseIsEqual(to: webviewURL) {
                print("Changing webview to current active URL!")
                let myRequest = URLRequest(url: webviewURL)
                self.webView.load(myRequest)
            }
        }
    }

    @objc func refreshWebView(_ sender: UIBarButtonItem) {
        let redirectOrReload = {
            if self.webView.isLoading {
                self.webView.stopLoading()
            } else if let webviewURL = Current.settingsStore.connectionInfo?.webviewURL {
                self.webView.load(URLRequest(url: webviewURL))
            } else {
                self.webView.reload()
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
            api.getAndSendLocation(trigger: .Manual)
        }.done {_ in
            print("Sending current location via button press")
            let alert = UIAlertController(title: L10n.ManualLocationUpdateNotification.title,
                                          message: L10n.ManualLocationUpdateNotification.message,
                                          preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }.catch {error in
            let nserror = error as NSError
            let message = L10n.ManualLocationUpdateFailedNotification.message(nserror.localizedDescription)
            let alert = UIAlertController(title: L10n.ManualLocationUpdateFailedNotification.title,
                                          message: message,
                                          preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    func updateWebViewSettings() {
        if let apiPass = keychain["apiPassword"] {
            self.webView.evaluateJavaScript("localStorage.getItem(\"authToken\")") { (result, error) in
                var storedPass = ""
                if result != nil, let resString = result as? String {
                    storedPass = resString
                }
                if error != nil || result == nil || storedPass != apiPass {
                    print("Setting password into LocalStorage")
                    self.webView.evaluateJavaScript("localStorage.setItem(\"authToken\", \"\(apiPass)\")") { (_, _) in
                        self.webView.reload()
                    }
                }
            }
        }
    }

    func userReconnected() {
        self.updateWebViewSettings()
        self.loadActiveURLIfNeeded()
    }
}

extension WebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "getExternalAuth", let messageBody = message.body as? [String: Any],
            let callbackName = messageBody["callback"] {
            if let tokenManager = Current.tokenManager {
                print("Callback hit")
                tokenManager.authDictionaryForWebView.done { dictionary in
                    let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: [])
                    if let jsonString = String(data: jsonData!, encoding: .utf8) {
                        let script = "\(callbackName)(true, \(jsonString))"
                        self.webView.evaluateJavaScript(script, completionHandler: { (result, error) in
                            if let error = error {
                                print("We failed: \(error)")
                            }

                            print("Success: \(result ?? "No result returned")")
                        })
                    }
                }.catch { error in
                    self.webView.evaluateJavaScript("\(callbackName)(false, 'Token unavailable')")
                    print("Failed to authenticate webview: \(error)")
                }
            } else {
                self.webView.evaluateJavaScript("\(callbackName)(false, 'Token unavailable')")
                print("Failed to authenticate webview. Token Unavailable")
            }
        } else if message.name == "revokeExternalAuth", let messageBody = message.body as? [String: Any],
            let callbackName = messageBody["callback"], let tokenManager = Current.tokenManager {

            print("Time to revoke the access token!")

            tokenManager.revokeToken().done { _ in
                Current.tokenManager = nil
                Current.settingsStore.connectionInfo = nil
                Current.settingsStore.tokenInfo = nil
                self.showSettingsViewController()
                let script = "\(callbackName)(true)"

                print("Running callback", script)

                self.webView.evaluateJavaScript(script, completionHandler: { (result, error) in
                    if let error = error {
                        print("Failed calling sign out callback: \(error)")
                    }

                    print("Successfully informed web client of log out.")
                })
            }.catch { error in
                print("Failed to revoke token", error)
            }
        }
    }
}

extension ConnectionInfo {
    var webviewURL: URL? {
        guard var components = URLComponents(url: self.activeURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        if Current.settingsStore.tokenInfo != nil {
            let queryItem = URLQueryItem(name: "external_auth", value: "1")
            components.queryItems = [queryItem]
        }

        return try? components.asURL()
    }
}
