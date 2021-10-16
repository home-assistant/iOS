import Foundation
import Shared

struct OnboardingAuthenticationError: LocalizedError {
    enum ErrorKind {
        case invalidURL
        case basicAuth
        case authenticationUnsupported(String)
        case sslUntrusted(Error)
        case clientCertificateRequired(Error)
        case other(Error)

        var documentationAnchor: String {
            switch self {
            case .basicAuth: return "basic_auth"
            case .invalidURL: return "invalid_url"
            case .authenticationUnsupported: return "authentication_unsupported"
            case .sslUntrusted: return "ssl_untrusted"
            case .clientCertificateRequired: return "client_certificate"
            case .other: return "unknown_error"
            }
        }
    }

    var kind: ErrorKind
    var data: Data?

    init(kind: OnboardingAuthenticationError.ErrorKind, data: Data? = nil) {
        self.kind = kind
        self.data = data
    }

    var errorCode: String? {
        switch kind {
        case .basicAuth: return nil
        case .authenticationUnsupported: return nil
        case .invalidURL: return nil
        case let .sslUntrusted(underlying as NSError),
             let .clientCertificateRequired(underlying as NSError),
             let .other(underlying as NSError):
            return String(format: "%@ %d", underlying.domain, underlying.code)
        }
    }

    var errorDescription: String? {
        switch kind {
        case .invalidURL:
            return L10n.errorLabel
        case .basicAuth:
            return L10n.Onboarding.ConnectionTestResult.BasicAuth.description
        case let .authenticationUnsupported(method):
            return L10n.Onboarding.ConnectionTestResult.AuthenticationUnsupported.description(" " + method)
        case let .clientCertificateRequired(underlying):
            return L10n.Onboarding.ConnectionTestResult.ClientCertificate.description
                + "\n\n" + underlying.localizedDescription
        case let .sslUntrusted(underlying),
             let .other(underlying):
            return underlying.localizedDescription
        }
    }

    var responseString: String? {
        guard let data = data, let dataString = String(data: data, encoding: .utf8) else {
            return nil
        }

        let displayDataString: String

        let maximumLength = 1024
        if dataString.count > maximumLength {
            displayDataString = dataString.prefix(maximumLength - 1) + "…"
        } else {
            displayDataString = dataString
        }

        return displayDataString
    }
}
