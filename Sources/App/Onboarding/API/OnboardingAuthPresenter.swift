import Foundation
import Shared

/// Presentation state for the onboarding flow. Auth steps ask this object to show UI instead of
/// presenting `UIViewController`s themselves; `OnboardingNavigationView` binds `path` to its
/// `NavigationStack` and renders the alert/sheet requests.
final class OnboardingAuthPresenter: ObservableObject {
    /// The onboarding navigation stack. Auth steps append their pages (login web view, device naming,
    /// permissions) so each step is a real push.
    @Published var path: [OnboardingDestination] = []
    /// A server-trust confirmation the connectivity step wants answered via an alert.
    @Published var certificateTrustRequest: OnboardingCertificateTrustRequest?
    /// A client-certificate (mTLS) import prompt shown as a sheet.
    @Published var clientCertificateRequest: OnboardingClientCertificateRequest?

    func push(_ destination: OnboardingDestination) {
        onMain { self.path.append(destination) }
    }

    /// Pops every auth flow page, returning to the servers list — called when the flow ends in
    /// failure or cancellation.
    func popAuthFlow() {
        onMain { self.path.removeAll(where: \.isAuthFlowStep) }
    }

    func popToRoot() {
        onMain { self.path.removeAll() }
    }

    func present(certificateTrustRequest request: OnboardingCertificateTrustRequest) {
        onMain { self.certificateTrustRequest = request }
    }

    func present(clientCertificateRequest request: OnboardingClientCertificateRequest) {
        onMain { self.clientCertificateRequest = request }
    }

    func dismissClientCertificateRequest() {
        onMain { self.clientCertificateRequest = nil }
    }

    /// Auth steps resolve on PromiseKit's main queue, but network delegates can call in from other
    /// threads; published state must only change on the main thread.
    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}
