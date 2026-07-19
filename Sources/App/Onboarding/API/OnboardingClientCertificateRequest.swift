import Foundation
import Shared

/// A request from `OnboardingAuthStepClientCertificate` to import a client certificate (mTLS), shown as
/// a sheet. Completing or cancelling resolves the step exactly once; an interactive sheet dismissal
/// counts as a cancellation.
final class OnboardingClientCertificateRequest: Identifiable {
    private let onImport: (ClientCertificate) -> Void
    private let onCancel: () -> Void
    private var isCompleted = false

    init(onImport: @escaping (ClientCertificate) -> Void, onCancel: @escaping () -> Void) {
        self.onImport = onImport
        self.onCancel = onCancel
    }

    func complete(with certificate: ClientCertificate) {
        guard !isCompleted else { return }
        isCompleted = true
        onImport(certificate)
    }

    func cancel() {
        guard !isCompleted else { return }
        isCompleted = true
        onCancel()
    }
}
