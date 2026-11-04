import Foundation

/// A request from `OnboardingAuthStepConnectivity` to confirm trusting a server certificate that failed
/// evaluation. Answered exactly once — either from the alert's buttons or not at all (the alert can only
/// be dismissed through its buttons).
final class OnboardingCertificateTrustRequest: Identifiable {
    let message: String
    private(set) var isAnswered = false

    private let onTrust: () -> Void
    private let onDontTrust: () -> Void

    init(message: String, onTrust: @escaping () -> Void, onDontTrust: @escaping () -> Void) {
        self.message = message
        self.onTrust = onTrust
        self.onDontTrust = onDontTrust
    }

    func trust() {
        answer(with: onTrust)
    }

    func dontTrust() {
        answer(with: onDontTrust)
    }

    private func answer(with handler: () -> Void) {
        guard !isAnswered else { return }
        isAnswered = true
        handler()
    }
}
