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
let kAuthenticationPath = "/auth/authorize?response_type=code&client_id=https%3A//blackgold9.github.io"
    + "/home-assistant-iOS&redirect_uri=homeassistant%3A%2F%2Fauth-callback"

class AuthenticationController: NSObject, SFSafariViewControllerDelegate {
    enum AuthenticationControllerError: Error {
        case invalidURL
        case userCancelled
    }

    private var promiseResolver: Resolver<String>?
    private var authenticationObserver: NSObjectProtocol?
    private var authenticationViewController: SFSafariViewController?
    var presentAuthenticationViewController: ((UIViewController) -> Void)?

    override init() {
        super.init()
        self.configureAuthenticationObserver()
    }

    func authenticateWithBrowser(at baseURL: URL) -> Promise<String> {
        return Promise { (resolver: Resolver<String>) in
            self.promiseResolver = resolver
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.path = "/auth/authorize"
            let responseTypeQuery = URLQueryItem(name: "response_type", value: "code")
            let clientIDQuery = URLQueryItem(name: "client_id", value: "https://blackgold9.github.io/home-assistant-iOS")
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
                self.presentAuthenticationViewController?(safariVC)
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

        controller.dismiss(animated: true, completion: nil)
        resolver.reject(AuthenticationControllerError.userCancelled)
        self.cleanUp()
    }

    // MARK: - Private helpers

    private func configureAuthenticationObserver() {
        let notificationCenter = NotificationCenter.default
        let notificationName = Notification.Name("AuthCallback")
        self.authenticationObserver = notificationCenter.addObserver(forName: notificationName, object: nil,
                                                                     queue: OperationQueue.main)
        { notification in
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
            self.cleanUp()
        }
    }

    private func cleanUp() {
        self.authenticationViewController = nil
        self.promiseResolver = nil
    }
}
