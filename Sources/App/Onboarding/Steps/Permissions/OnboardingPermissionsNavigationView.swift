import Shared
import SwiftUI

// This view handles navigation between different permission request steps during onboarding.
// It is not using NavigationView/Stack because for some unknown reason location permission dialog
// is popping the screen and no solution was found to prevent that until now.
struct OnboardingPermissionsNavigationView: View {
    @StateObject private var viewModel: OnboardingPermissionsNavigationViewModel

    let onboardingServer: Server

    @Environment(\.layoutDirection) private var layoutDirection

    init(onboardingServer: Server) {
        self
            ._viewModel =
            .init(wrappedValue: OnboardingPermissionsNavigationViewModel(onboardingServer: onboardingServer))
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
        LocalAccessPermissionView { localAccessSecurityLevel in
            switch localAccessSecurityLevel {
            case .undefined:
                assertionFailure("undefined should not be possible here")
            case .mostSecure:
                viewModel.requestLocationPermissionForSecureLocalConnection()
            case .lessSecure:
                viewModel.setLessSecureLocalConnection()
                viewModel.navigateToStep(.completion)
            }
        }
    }

    private var homeNetworkInput: some View {
        HomeNetworkInputView(onNext: { networkSSID in
            if let networkSSID {
                viewModel.saveNetworkSSID(networkSSID)
            }
            navigateToCompletionScreen()
        }, onSkip: {
            navigateToCompletionScreen()
        })
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
