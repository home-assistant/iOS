import Foundation
import Shared
import SwiftUI

/// Presentation state for the onboarding flow. Auth steps ask this object to show UI instead of
/// presenting `UIViewController`s themselves; `OnboardingNavigationView` binds `path` to its
/// `NavigationStack` and renders the alert/sheet requests.
final class OnboardingAuthPresenter: ObservableObject {
    /// The onboarding navigation stack. Auth steps append their pages (login web view, device naming,
    /// permissions) so each step is a real push.
    @Published var path: [OnboardingDestination] = []
    /// A server-trust confirmation the connectivity step wants answered via an alert.
    @Published var certificateTrustRequest: OnboardingCertificateTrustRequest?
    /// A client-certificate (mTLS) import prompt shown as a sheet. iOS only — Mac Catalyst pushes
    /// the import step onto `path` instead.
    @Published var clientCertificateRequest: OnboardingClientCertificateRequest?
    /// iOS only. While true, the client-certificate sheet is held back. Screens that present their
    /// own sheet (manual URL entry) set this so the prompt is only shown after their sheet fully
    /// dismissed — presenting both at once can leave the prompt stranded behind the other sheet.
    /// Deliberately NOT `@Published`: it flips as that sheet presents, and publishing then would
    /// re-render the container mid-transition. `releaseClientCertificateHold()` republishes once
    /// it's safe.
    var holdClientCertificateSheet = false

    /// Called when the sheet that was holding the prompt back has fully dismissed. If a certificate
    /// request arrived while it was up, republish so the container presents it now.
    func releaseClientCertificateHold() {
        holdClientCertificateSheet = false
        if clientCertificateRequest != nil {
            onMain { self.objectWillChange.send() }
        }
    }

    func push(_ destination: OnboardingDestination) {
        onMain { self.path.append(destination) }
    }

    /// Pops every auth flow page, returning to the servers list — called when the flow ends in
    /// failure or cancellation. Pops without animation: a follow-up push (the error page on Mac
    /// Catalyst) would be dropped if it lands while the pop transition is still running.
    func popAuthFlow() {
        onMain {
            self.withoutAnimation {
                self.path.removeAll(where: \.isAuthFlowStep)
            }
        }
    }

    func popToRoot() {
        onMain { self.path.removeAll() }
    }

    func present(certificateTrustRequest request: OnboardingCertificateTrustRequest) {
        onMain { self.certificateTrustRequest = request }
    }

    /// On Mac Catalyst the import step is pushed as a page — sheet content doesn't receive mouse
    /// events reliably there; iOS keeps the sheet presentation.
    func present(clientCertificateRequest request: OnboardingClientCertificateRequest) {
        onMain {
            if Current.isCatalyst {
                self.path.append(.clientCertificate(request))
            } else {
                self.clientCertificateRequest = request
            }
        }
    }

    func dismissClientCertificateRequest() {
        onMain {
            if Current.isCatalyst {
                // Without animation so the pages that follow (login on success, the error page on
                // cancel) aren't dropped by landing mid-transition.
                self.withoutAnimation {
                    self.path.removeAll { destination in
                        if case .clientCertificate = destination { return true }
                        return false
                    }
                }
            } else {
                self.clientCertificateRequest = nil
            }
        }
    }

    private func withoutAnimation(_ block: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, block)
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
