import Foundation
import Shared

class OnboardingAuthDetails: Equatable {
    var url: URL
    var scheme: String
    var exceptions: SecurityExceptions = .init()

    init(baseURL: URL) throws {
        guard var components = URLComponents(url: baseURL.sanitized(), resolvingAgainstBaseURL: false) else {
            throw OnboardingAuthError(kind: .invalidURL)
        }

        let redirectURI: String
        let scheme: String
        let clientID: String

        if Current.appConfiguration == .Debug {
            clientID = "https://home-assistant.io/iOS/dev-auth"
            redirectURI = "homeassistant-dev://auth-callback"
            scheme = "homeassistant-dev"
        } else if Current.appConfiguration == .Beta {
            clientID = "https://home-assistant.io/iOS/beta-auth"
            redirectURI = "homeassistant-beta://auth-callback"
            scheme = "homeassistant-beta"
        } else {
            clientID = "https://home-assistant.io/iOS"
            redirectURI = "homeassistant://auth-callback"
            scheme = "homeassistant"
        }

        components.path += "/auth/authorize"
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
        ]

        guard let authURL = components.url else {
            throw OnboardingAuthError(kind: .invalidURL)
        }

        self.url = authURL
        self.scheme = scheme
    }

    static func == (lhs: OnboardingAuthDetails, rhs: OnboardingAuthDetails) -> Bool {
        lhs.url == rhs.url && lhs.scheme == rhs.scheme && lhs.exceptions == rhs.exceptions
    }
}
