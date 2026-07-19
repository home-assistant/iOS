import Shared
import SwiftUI

/// Renders a single permissions step and pushes the next one onto the enclosing `NavigationStack`.
///
/// Each visible step owns the push to its successor (via `advance` from the shared view model), so
/// navigation is always driven by an on-screen view. This avoids two iOS 16 `NavigationStack` pitfalls
/// hit during onboarding: a cross-view path mutation isn't observed after the UIKit auth modals dismiss,
/// and nesting a second `NavigationStack` resets the outer one.
struct OnboardingPermissionsStepView: View {
    let step: OnboardingPermissionsNavigationViewModel.StepID
    @ObservedObject var viewModel: OnboardingPermissionsNavigationViewModel

    @State private var pushedStep: OnboardingPermissionsNavigationViewModel.StepID?

    var body: some View {
        content
            .navigationDestination(isPresented: Binding(
                get: { pushedStep != nil },
                set: { if !$0 { pushedStep = nil } }
            )) {
                if let pushedStep {
                    OnboardingPermissionsStepView(step: pushedStep, viewModel: viewModel)
                        .navigationBarBackButtonHidden()
                }
            }
            .onReceive(viewModel.advance) { transition in
                guard transition.from == step else { return }
                pushedStep = transition.to
            }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .disclaimer:
            LocalAccessOnlyDisclaimerView {
                viewModel.nextStep()
            }
        case .location:
            LocationPermissionView {
                viewModel.requestLocationPermissionToShareWithHomeAssistant()
            } secondaryAction: {
                viewModel.disableLocationSensor()
                viewModel.nextStep()
            }
        case .localAccess:
            LocalAccessPermissionView { connectionAccessSecurityLevel in
                switch connectionAccessSecurityLevel {
                case .undefined:
                    assertionFailure("undefined should not be possible here")
                case .mostSecure:
                    viewModel.requestLocationPermissionForSecureLocalConnection()
                case .lessSecure:
                    viewModel.requestLocationPermissionForLessSecureLocalConnection()
                }
            }
        case .homeNetwork:
            HomeNetworkInputView(onNext: { context in
                if context.networkName != nil || context.hardwareAddress != nil {
                    viewModel.saveHomeNetwork(context)
                }
            })
            .onChange(of: viewModel.storedSSIDSuccessfully) { newValue in
                if newValue {
                    viewModel.nextStep()
                }
            }
        case .completion:
            // Reaching `.completion` finishes the flow in the view model instead of pushing a screen.
            Color.clear
        case .updatePreferencesSuccess:
            // View that display success animation and dismisses the flow shortly after
            CheckmarkDrawOnView()
                .onAppear {
                    // Dismiss after a short delay to allow the user to see the success state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        viewModel.finishFlow()
                    }
                }
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingPermissionsStepView(
            step: .location,
            viewModel: OnboardingPermissionsNavigationViewModel(onboardingServer: ServerFixture.standard)
        )
    }
}
