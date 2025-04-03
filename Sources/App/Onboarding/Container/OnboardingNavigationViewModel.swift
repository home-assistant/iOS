import Foundation
import Shared

final class OnboardingNavigationViewModel: ObservableObject {
    @Published var shouldDismiss: Bool = false

    init() {
        Current.onboardingObservation.register(observer: self)
    }

    deinit {
        Current.onboardingObservation.unregister(observer: self)
    }
}

extension OnboardingNavigationViewModel: OnboardingStateObserver {
    func onboardingStateDidChange(to state: OnboardingState) {
        guard state == .complete else { return }
        DispatchQueue.main.async { [weak self] in
            self?.shouldDismiss = true
        }
    }
}
