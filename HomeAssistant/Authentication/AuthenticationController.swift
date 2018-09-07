//
//  AuthenticationController.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 8/11/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import PromiseKit
import SafariServices
import Shared

/// Manages browser verification to retrive an access code that can be exchanged for an authentication token.
class AuthenticationController: NSObject, SFSafariViewControllerDelegate {
    enum AuthenticationControllerError: Error {
        case invalidURL
        case userCancelled
    }

    private var promiseResolver: Resolver<String>?
    private var authenticationObserver: NSObjectProtocol?
    private var authenticationViewController: SFSafariViewController?

    override init() {
        super.init()
        self.configureAuthenticationObserver()
    }

    /// Opens a browser to the URL for obtaining an access code.
    func authenticateWithBrowser(at baseURL: URL) -> Promise<String> {
        return Promise { (resolver: Resolver<String>) in
            self.promiseResolver = resolver
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.path = "/auth/authorize"
            let responseTypeQuery = URLQueryItem(name: "response_type", value: "code")
            let clientIDQuery = URLQueryItem(name: "client_id",
                                             value: "https://home-assistant.io/iOS")
            let redirectQuery = URLQueryItem(name: "redirect_uri", value: "homeassistant://auth-callback")
            components?.queryItems = [responseTypeQuery, clientIDQuery, redirectQuery]
            if let newURL = try components?.asURL() {
                let safariVC = SFSafariViewController(url: newURL)
                if #available(iOS 11.0, *) {
                    safariVC.dismissButtonStyle = .cancel
                } else {
                    // Fallback on earlier versions
                }
                safariVC.delegate = self
                self.authenticationViewController = safariVC
                Current.authenticationControllerPresenter?(safariVC)
            } else {
                resolver.reject(AuthenticationControllerError.invalidURL)
            }
        }
    }

    // MARK: - SFSafariViewControllerDelegate

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        guard let resolver = self.promiseResolver  else {
            return
        }

        resolver.reject(AuthenticationControllerError.userCancelled)
        self.cleanUp()
    }

    // MARK: - Private helpers

    private func configureAuthenticationObserver() {
        let notificationCenter = NotificationCenter.default
        let notificationName = Notification.Name("AuthCallback")
        let queue = OperationQueue.main
        self.authenticationObserver = notificationCenter.addObserver(forName: notificationName, object: nil,
                                                                     queue: queue) { notification in
            self.authenticationViewController?.dismiss(animated: true, completion: nil)
            guard let url = notification.userInfo?["url"] as? URL,
                let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
                    return
            }

            let parameter = components.queryItems?.first(where: { (item) -> Bool in
                item.name == "code"
            })

            if let codeParamter = parameter, let code = codeParamter.value {
                self.promiseResolver?.fulfill(code)
            }
            self.authenticationViewController?.dismiss(animated: true, completion: nil)
            self.cleanUp()
        }
    }

    private func cleanUp() {
        self.authenticationViewController = nil
        self.promiseResolver = nil
    }
}
