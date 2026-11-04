import Foundation
import Shared

enum ServerReauthenticationError: LocalizedError, Equatable {
    /// The server asks for a client certificate this device has not been given.
    case clientCertificateRequired(String)

    var errorDescription: String? {
        switch self {
        case let .clientCertificateRequired(serverName):
            return L10n.RestoredRegistrations.Errors.clientCertificateRequired(serverName)
        }
    }
}
