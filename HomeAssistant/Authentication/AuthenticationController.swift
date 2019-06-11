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
import AuthenticationServices
import Shared

/// Manages browser verification to retrive an access code that can be exchanged for an authentication token.
class AuthenticationController: NSObject {

    enum AuthenticationControllerError: Error {
        case invalidURL
        case userCancelled
        case cantFindURLHandler
    }

    private var promiseResolver: Resolver<String>?
    private var authenticationObserver: NSObjectProtocol?
    private var authenticationViewController: Any?
    private var authStyle: String = "SFAuthenticationSession"

    override init() {
        super.init()
        self.configureAuthenticationObserver()
    }

    var clientID: String {
        var clientID = "https://home-assistant.io/iOS"

        if Current.appConfiguration == .Debug {
            clientID = "https://home-assistant.io/iOS/dev-auth"
        } else if Current.appConfiguration == .Beta {
            clientID = "https://home-assistant.io/iOS/beta-auth"
        }

        return clientID
    }

    var redirectURI: String {
        var redirectURI = "homeassistant://auth-callback"

        if Current.appConfiguration == .Debug {
            redirectURI = "homeassistant-dev://auth-callback"
        } else if Current.appConfiguration == .Beta {
            redirectURI = "homeassistant-beta://auth-callback"
        }

        return redirectURI
    }

    func authURL(_ baseURL: URL) -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = "/auth/authorize"
        let responseTypeQuery = URLQueryItem(name: "response_type", value: "code")
        let clientIDQuery = URLQueryItem(name: "client_id", value: self.clientID)
        let redirectQuery = URLQueryItem(name: "redirect_uri", value: self.redirectURI)
        components?.queryItems = [responseTypeQuery, clientIDQuery, redirectQuery]

        return components?.url
    }

    /// Opens a browser to the URL for obtaining an access code.
    func authenticateWithBrowser(at baseURL: URL, view: UIViewController? = nil) -> Promise<String> {
        return Promise { (resolver: Resolver<String>) in
            self.promiseResolver = resolver

            guard let authURL = self.authURL(baseURL) else {
                resolver.reject(AuthenticationControllerError.invalidURL)
                return
            }

            let newStyleAuthCallback = { (callbackURL: URL?, error: Error?) in
                if let authErr = error {
                    Current.Log.error("Error during \(self.authStyle) authentication: \(authErr)")
                    return
                }

                guard let successURL = callbackURL else {
                    Current.Log.error("CallbackURL was empty during \(self.authStyle) authentication")
                    return
                }

                self.handleSuccess(successURL)
            }

            if #available(iOS 12.0, *) {
                self.authStyle = "ASWebAuthenticationSession"
                let webAuthSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: self.redirectURI,
                                                                completionHandler: newStyleAuthCallback)

                if #available(iOS 13.0, *) {
                    // swiftlint:disable:next line_length force_cast
                    webAuthSession.presentationContextProvider = (view as! ASWebAuthenticationPresentationContextProviding)
                    webAuthSession.prefersEphemeralWebBrowserSession = true
                }
                webAuthSession.start()

                self.authenticationViewController = webAuthSession
            } else if #available(iOS 11.0, *) {
                self.authStyle = "SFAuthenticationSession"
                let webAuthSession = SFAuthenticationSession(url: authURL, callbackURLScheme: self.redirectURI,
                                                             completionHandler: newStyleAuthCallback)

                webAuthSession.start()

                self.authenticationViewController = webAuthSession
            }
        }
    }

    // MARK: - Private helpers

    private func configureAuthenticationObserver() {
        let notificationCenter = NotificationCenter.default
        let notificationName = Notification.Name("AuthCallback")
        let queue = OperationQueue.main
        self.authenticationObserver = notificationCenter.addObserver(forName: notificationName, object: nil,
                                                                     queue: queue) { notification in
            if #available(iOS 12.0, *) {
                (self.authenticationViewController as? ASWebAuthenticationSession)?.cancel()
            } else if #available(iOS 11.0, *) {
                (self.authenticationViewController as? SFAuthenticationSession)?.cancel()
            }
            guard let url = notification.userInfo?["url"] as? URL else {
                    return
            }

            self.handleSuccess(url)

            if #available(iOS 12.0, *) {
                (self.authenticationViewController as? ASWebAuthenticationSession)?.cancel()
            } else if #available(iOS 11.0, *) {
                (self.authenticationViewController as? SFAuthenticationSession)?.cancel()
            }

            self.cleanUp()
        }
    }

    private func handleSuccess(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return
        }

        let parameter = components.queryItems?.first(where: { (item) -> Bool in
            item.name == "code"
        })

        if let codeParamter = parameter, let code = codeParamter.value {
            Current.Log.verbose("Returning from authentication with code \(code)")
            self.promiseResolver?.fulfill(code)
        }
    }

    private func cleanUp() {
        self.authenticationViewController = nil
        self.promiseResolver = nil
    }
}
