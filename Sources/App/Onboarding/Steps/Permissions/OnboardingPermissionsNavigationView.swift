import Shared
import SwiftUI

// This view handles navigation between different permission request steps during onboarding.
// It is not using NavigationView/Stack because for some unknown reason location permission dialog
// is popping the screen and no solution was found to prevent that until now.
struct OnboardingPermissionsNavigationView: View {
    @StateObject private var viewModel: OnboardingPermissionsNavigationViewModel

    let onboardingServer: Server

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.dismiss) private var dismiss

    init(onboardingServer: Server, steps: [OnboardingPermissionsNavigationViewModel.StepID]? = nil) {
        self
            ._viewModel =
            .init(wrappedValue: OnboardingPermissionsNavigationViewModel(
                onboardingServer: onboardingServer,
                steps: steps
            ))
        self.onboardingServer = onboardingServer
    }

    var body: some View {
        ZStack {
            ForEach(Array(viewModel.steps.enumerated()), id: \.element) { index, stepId in
                if index == viewModel.currentStepIndex {
                    stepView(for: stepId)
                        .transition(pushTransition)
                        .id(stepId)
                        .zIndex(Double(index))
                }
            }
        }
        .animation(DesignSystem.Animation.default, value: viewModel.currentStepIndex)
    }

    @ViewBuilder
    private func stepView(for stepId: OnboardingPermissionsNavigationViewModel.StepID) -> some View {
        switch stepId {
        case .disclaimer:
            disclaimer
        case .location:
            location
        case .localAccess:
            localAccess
        case .homeNetwork:
            homeNetworkInput
        case .completion:
            completionView
        case .updatePreferencesSuccess:
            checkmarkSuccessView
        }
    }

    private var disclaimer: some View {
        LocalAccessOnlyDisclaimerView {
            viewModel.nextStep()
        }
    }

    private var location: some View {
        LocationPermissionView {
            viewModel.requestLocationPermissionToShareWithHomeAssistant()
        } secondaryAction: {
            viewModel.disableLocationSensor()
            viewModel.nextStep()
        }
    }

    private var localAccess: some View {
        LocalAccessPermissionView { connectionAccessSecurityLevel in
            switch connectionAccessSecurityLevel {
            case .undefined:
                assertionFailure("undefined should not be possible here")
            case .mostSecure:
                viewModel.requestLocationPermissionForSecureLocalConnection()
            case .lessSecure:
                viewModel.setLessSecureLocalConnection()
                if viewModel.steps.contains(.completion) {
                    viewModel.navigateToStep(.completion)
                } else if viewModel.steps.contains(.updatePreferencesSuccess) {
                    viewModel.navigateToStep(.updatePreferencesSuccess)
                }
            }
        }
    }

    private var homeNetworkInput: some View {
        HomeNetworkInputView(onNext: { networkSSID in
            if let networkSSID {
                viewModel.saveNetworkSSID(networkSSID)
            }
        })
        .onChange(of: viewModel.storedSSIDSuccessfully) { newValue in
            if newValue {
                navigateToCompletionScreen()
            }
        }
    }

    private var completionView: some View {
        // Empty screen that will fade out
        Color.clear
            .onAppear {
                // Start fade out animation after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    viewModel.completeOnboarding()
                }
            }
    }

    private var checkmarkSuccessView: some View {
        // View that display success animation and dismisses the flow shortly after
        CheckmarkDrawOnView()
            .onAppear {
                // Dismiss after a short delay to allow the user to see the success state
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    dismiss()
                }
            }
    }

    private func navigateToCompletionScreen() {
        viewModel.nextStep()
    }

    // MARK: - Animation

    // Mimics UINavigationController push/pop animation

    private var pushTransition: AnyTransition {
        // Special handling for completion screen - always fade out
        if viewModel.currentStepIndex == viewModel.steps.count - 1, viewModel.currentStep == .completion {
            return .opacity
        }

        // Respect layout direction (RTL vs LTR)
        let leading: Edge = layoutDirection == .leftToRight ? .leading : .trailing
        let trailing: Edge = layoutDirection == .leftToRight ? .trailing : .leading

        // Forward: insert from trailing, remove to leading (push)
        // Backward: insert from leading, remove to trailing (pop)
        let insertionEdge: Edge = viewModel.isAdvancing ? trailing : leading
        let removalEdge: Edge = viewModel.isAdvancing ? leading : trailing

        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }
}

#Preview {
    OnboardingPermissionsNavigationView(onboardingServer: ServerFixture.standard)
}

#Preview("Custom Steps") {
    OnboardingPermissionsNavigationView(
        onboardingServer: ServerFixture.standard,
        steps: [.location, .localAccess, .completion]
    )
}
