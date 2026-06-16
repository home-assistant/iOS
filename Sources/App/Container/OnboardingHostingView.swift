import SwiftUI

/// Hosts onboarding in a `UIHostingController` (via `embeddedInHostingController()`) so the
/// `ViewControllerProvider` the flow expects is injected. `makeUIViewController` runs once per identity,
/// so the controller and provider are created a single time rather than on every `body` re-evaluation.
struct OnboardingHostingView: UIViewControllerRepresentable {
    let onboardingStyle: OnboardingStyle

    func makeUIViewController(context: Context) -> UIViewController {
        OnboardingNavigationView(onboardingStyle: onboardingStyle).embeddedInHostingController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
