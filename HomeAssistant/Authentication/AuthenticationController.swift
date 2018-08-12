//
//  AuthenticationController.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 8/11/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import SafariServices
let kAuthenticationPath = "/auth/authorize.html?response_type=code&client_id=https%3A%2F%2Fblackgold9.github.io%2Fhome-assistant-iOS%2F&redirect_uri=homeassistant%3A%2F%2Fauth-callback"
class AuthenticationController {
    func authenticateWithBaseURL(baseURL: URL) {
        let safariVC = SFSafariViewController.init(url: baseURL.appendingPathComponent(kAuthenticationPath))
        
    }
}
