import Foundation
import Shared

/// A page pushed onto the onboarding `NavigationStack`. The welcome screen (or the servers list, for
/// secondary onboarding) is the root; everything else is a real push driven by
/// `OnboardingAuthPresenter.path`.
enum OnboardingDestination: Hashable {
    case serversList
    case login(OnboardingAuthLoginViewModel)
    case deviceName(OnboardingDeviceNameRequest)
    case permissions(Server)
    /// The client-certificate (mTLS) import step. Only used on Mac Catalyst, where sheet content
    /// doesn't receive mouse events reliably; iOS presents the same view as a sheet instead.
    case clientCertificate(OnboardingClientCertificateRequest)
    /// The connection-error details. Only used on Mac Catalyst, for the same reason as above.
    case connectionError(OnboardingConnectionErrorContext)

    /// Whether this page belongs to the auth flow (everything after the user picked a server).
    var isAuthFlowStep: Bool {
        switch self {
        case .serversList, .connectionError: return false
        case .login, .deviceName, .permissions, .clientCertificate: return true
        }
    }

    static func == (lhs: OnboardingDestination, rhs: OnboardingDestination) -> Bool {
        switch (lhs, rhs) {
        case (.serversList, .serversList):
            return true
        case let (.login(lhsViewModel), .login(rhsViewModel)):
            return lhsViewModel === rhsViewModel
        case let (.deviceName(lhsRequest), .deviceName(rhsRequest)):
            return lhsRequest === rhsRequest
        case let (.permissions(lhsServer), .permissions(rhsServer)):
            return lhsServer.identifier == rhsServer.identifier
        case let (.clientCertificate(lhsRequest), .clientCertificate(rhsRequest)):
            return lhsRequest === rhsRequest
        case let (.connectionError(lhsContext), .connectionError(rhsContext)):
            return lhsContext === rhsContext
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .serversList:
            hasher.combine(0)
        case let .login(viewModel):
            hasher.combine(1)
            hasher.combine(ObjectIdentifier(viewModel))
        case let .deviceName(request):
            hasher.combine(2)
            hasher.combine(ObjectIdentifier(request))
        case let .permissions(server):
            hasher.combine(3)
            hasher.combine(server.identifier)
        case let .clientCertificate(request):
            hasher.combine(4)
            hasher.combine(ObjectIdentifier(request))
        case let .connectionError(context):
            hasher.combine(5)
            hasher.combine(ObjectIdentifier(context))
        }
    }
}
