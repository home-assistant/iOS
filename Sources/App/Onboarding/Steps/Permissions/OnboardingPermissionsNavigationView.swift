import Shared
import SwiftUI

// This view handles navigation between different permission request steps during onboarding.
// It is not using NavigationView/Stack because for some unknown reason location permission dialog
// is popping the screen and no solution was found to prevent that until now.
struct OnboardingPermissionsNavigationView: View {
    enum StepID: String, CaseIterable, Identifiable {
        case disclaimer
        case location
        case localAccess
        case homeNetwork
        case completion

        var id: String { rawValue }
    }

    struct Step: Identifiable {
        let id: StepID
        let index: Int
        let view: AnyView

        init(id: StepID, index: Int, @ViewBuilder view: () -> some View) {
            self.id = id
            self.index = index
            self.view = AnyView(view())
        }
    }

    @StateObject private var viewModel: OnboardingPermissionsNavigationViewModel
    @State private var currentStepIndex: Int = 0
    @State private var lastStepIndex: Int = 0

    let onboardingServer: Server

    @Environment(\.layoutDirection) private var layoutDirection

    private var steps: [Step] {
        [
            Step(id: .disclaimer, index: 0) {
                disclaimer
            },
            Step(id: .location, index: 1) {
                location
            },
            Step(id: .localAccess, index: 2) {
                localAccess
            },
            Step(id: .homeNetwork, index: 3) {
                homeNetworkInput
            },
            Step(id: .completion, index: 4) {
                completionView
            },
        ]
    }

    init(onboardingServer: Server) {
        self._viewModel = .init(wrappedValue: OnboardingPermissionsNavigationViewModel(onboardingServer: onboardingServer))
        self.onboardingServer = onboardingServer
    }

    var body: some View {
        ZStack {
            ForEach(steps) { step in
                if step.index == currentStepIndex {
                    step.view
                        .transition(pushTransition)
                        .id(step.id)
                        .zIndex(Double(step.index))
                }
            }
        }
        .animation(DesignSystem.Animation.default, value: currentStepIndex)
        .onChange(of: currentStepIndex) { newValue in
            // Update the last step after deciding transition direction
            lastStepIndex = newValue
        }
    }

    private func navigateToStep(at index: Int) {
        guard index >= 0, index < steps.count else { return }

        // Add haptic feedback for forward navigation
        if index > currentStepIndex {
            Current.impactFeedback.impactOccurred()
        }

        currentStepIndex = index
    }

    private func nextStep() {
        navigateToStep(at: currentStepIndex + 1)
    }

    private var disclaimer: some View {
        LocalAccessOnlyDisclaimerView {
            nextStep()
        }
    }

    private var location: some View {
        LocationPermissionView {
            viewModel.requestLocationPermissionToShareWithHomeAssistant()
        } secondaryAction: {
            viewModel.disableLocationSensor()
            nextStep()
        }
    }

    private var localAccess: some View {
        LocalAccessPermissionView {
            viewModel.requestLocationPermissionForSecureLocalConnection()
        } secondaryAction: {
            viewModel.setLessSecureLocalConnection()
            nextStep()
        }
    }

    private var homeNetworkInput: some View {
        HomeNetworkInputView(onNext: { networkSSID in
            if let networkSSID {
                saveNetworkSSID(networkSSID)
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
                    completeOnboarding()
                }
            }
    }

    private func saveNetworkSSID(_ ssid: String) {
        onboardingServer.update { info in
            info.connection.internalSSIDs = [ssid]
        }
    }

    private func navigateToCompletionScreen() {
        nextStep()
    }

    private func completeOnboarding() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Current.onboardingObservation.complete()
        }
    }

    // MARK: - Animation

    // Mimics UINavigationController push/pop animation

    private var isAdvancing: Bool {
        currentStepIndex >= lastStepIndex
    }

    private var pushTransition: AnyTransition {
        // Special handling for completion screen - always fade out
        if currentStepIndex == steps.count - 1, steps[currentStepIndex].id == .completion {
            return .opacity
        }

        // Respect layout direction (RTL vs LTR)
        let leading: Edge = layoutDirection == .leftToRight ? .leading : .trailing
        let trailing: Edge = layoutDirection == .leftToRight ? .trailing : .leading

        // Forward: insert from trailing, remove to leading (push)
        // Backward: insert from leading, remove to trailing (pop)
        let insertionEdge: Edge = isAdvancing ? trailing : leading
        let removalEdge: Edge = isAdvancing ? leading : trailing

        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }
}

#Preview {
    OnboardingPermissionsNavigationView(onboardingServer: ServerFixture.standard)
}
