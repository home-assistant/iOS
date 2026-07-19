import Foundation

/// A request from `OnboardingAuthStepDeviceNaming` for the user to name this device, pushed onto the
/// onboarding navigation stack. Name conflicts keep the screen up and surface `errorMessage` inline;
/// popping the screen (back button) cancels the auth flow.
final class OnboardingDeviceNameRequest: ObservableObject, Identifiable {
    @Published private(set) var errorMessage: String?
    /// True from a save attempt until it fails; on success the screen stays up (with the indicator)
    /// until the flow replaces it with the next step.
    @Published private(set) var isSaving = false

    private let onSave: (String, OnboardingDeviceNameRequest) -> Void
    private let onCancel: () -> Void
    private var isFinished = false

    init(onSave: @escaping (String, OnboardingDeviceNameRequest) -> Void, onCancel: @escaping () -> Void) {
        self.onSave = onSave
        self.onCancel = onCancel
    }

    func save(_ name: String) {
        guard !isFinished, !isSaving else { return }
        errorMessage = nil
        isSaving = true
        onSave(name, self)
    }

    /// Rejects a save attempt (name conflict or verification failure), keeping the screen up.
    func fail(with message: String) {
        errorMessage = message
        isSaving = false
    }

    /// Marks the request as successfully handled so the pop-triggered dismissal doesn't cancel.
    func finish() {
        isFinished = true
    }

    /// Called when the screen disappears; treats an unfinished dismissal (back button) as cancellation.
    func cancelAfterDismissal() {
        guard !isFinished else { return }
        isFinished = true
        onCancel()
    }
}
