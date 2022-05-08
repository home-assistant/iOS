import Foundation
import Shared

struct OnboardingAuthError: LocalizedError {
    enum ErrorKind: Equatable {
        case invalidURL
        case basicAuth
        case authenticationUnsupported(String)
        case sslUntrusted([Error])
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

        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.invalidURL, .invalidURL), (.basicAuth, .basicAuth):
                return true
            case let (.authenticationUnsupported(lhsMethod), .authenticationUnsupported(rhsMethod)):
                return lhsMethod == rhsMethod
            case let (.sslUntrusted(lhsErrors as [NSError]), .sslUntrusted(rhsError as [NSError])):
                return lhsErrors.map(\.code) == rhsError.map(\.code)
            case let (.clientCertificateRequired(lhsError as NSError), .clientCertificateRequired(rhsError as NSError)),
                 let (.other(lhsError as NSError), .other(rhsError as NSError)):
                return lhsError.domain == rhsError.domain &&
                    lhsError.code == rhsError.code
            default: return false
            }
        }
    }

    var kind: ErrorKind
    var data: Data?

    init(kind: OnboardingAuthError.ErrorKind, data: Data? = nil) {
        self.kind = kind
        self.data = data
    }

    var errorCode: String? {
        func code(from nsError: NSError) -> String {
            String(format: "%@ %d", nsError.domain, nsError.code)
        }

        switch kind {
        case .basicAuth: return nil
        case .authenticationUnsupported: return nil
        case .invalidURL: return nil
        case let .sslUntrusted(underlying as [NSError]):
            return Set(underlying.map { code(from: $0) }).joined(separator: "; ")
        case let .clientCertificateRequired(underlying as NSError),
             let .other(underlying as NSError):
            return code(from: underlying)
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
        case let .sslUntrusted(errors):
            // swift compiler crashes with \.localizedDescription below, xcode 13.3
            // swiftformat:disable:next preferKeyPath
            return errors.map { $0.localizedDescription }.joined(separator: "\n\n")
        case let .other(underlying):
            let extraInfo: String?

            if let urlError = underlying as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    extraInfo = L10n.Onboarding.ConnectionTestResult.LocalNetworkPermission.description
                default:
                    extraInfo = nil
                }
            } else {
                extraInfo = nil
            }

            if let extraInfo = extraInfo {
                return extraInfo + "\n\n" + underlying.localizedDescription
            } else {
                return underlying.localizedDescription
            }
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
