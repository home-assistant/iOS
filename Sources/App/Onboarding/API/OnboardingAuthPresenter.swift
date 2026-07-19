import Foundation
import Shared

/// Presentation state for the onboarding auth flow. Auth steps ask this object to show UI instead of
/// presenting `UIViewController`s themselves; the hosting SwiftUI screen (`OnboardingServersListView`)
/// observes it and renders the pushed screen, alert, or sheet.
final class OnboardingAuthPresenter: ObservableObject {
    /// The screen currently pushed onto the navigation stack (login web view or device naming).
    @Published var pushedDestination: OnboardingAuthDestination?
    /// A server-trust confirmation the connectivity step wants answered via an alert.
    @Published var certificateTrustRequest: OnboardingCertificateTrustRequest?
    /// A client-certificate (mTLS) import prompt shown as a sheet.
    @Published var clientCertificateRequest: OnboardingClientCertificateRequest?

    func push(_ destination: OnboardingAuthDestination) {
        onMain { self.pushedDestination = destination }
    }

    func pop() {
        onMain { self.pushedDestination = nil }
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
