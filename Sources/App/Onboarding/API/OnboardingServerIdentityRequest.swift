import Foundation

/// A request from `OnboardingAuthStepServerIdentity` to say whether the server being added, which
/// reports the same instance ID as one the app already has but answers at a different address,
/// replaces that server or stands next to it. Answered exactly once; dismissing the prompt without
/// choosing counts as cancelling.
final class OnboardingServerIdentityRequest: Identifiable {
    enum Decision {
        case separate
        case replace
    }

    let newServer: ServerIdentityConflictingServer
    let existingServer: ServerIdentityConflictingServer

    private let onDecision: (Decision) -> Void
    private let onCancel: () -> Void
    private var isAnswered = false

    init(
        newServer: ServerIdentityConflictingServer,
        existingServer: ServerIdentityConflictingServer,
        onDecision: @escaping (Decision) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.newServer = newServer
        self.existingServer = existingServer
        self.onDecision = onDecision
        self.onCancel = onCancel
    }

    func addAsSeparateServer() {
        answer { onDecision(.separate) }
    }

    func replaceExistingServer() {
        answer { onDecision(.replace) }
    }

    func cancel() {
        answer(with: onCancel)
    }

    private func answer(with handler: () -> Void) {
        guard !isAnswered else { return }
        isAnswered = true
        handler()
    }
}
