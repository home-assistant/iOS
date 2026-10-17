import SFSafeSymbols
import Shared
import SwiftUI

// This view handles navigation between different permission request steps during onboarding.
// It is not using NavigationView/Stack because for some unknown reason location permission dialog
// is popping the screen and no solution was found to prevent that until now.
struct OnboardingPermissionsNavigationView: View {
    @StateObject private var viewModel: OnboardingPermissionsNavigationViewModel

    let onboardingServer: Server
    private let onDismiss: (() -> Void)?
    /// Whether the navigation bar is only shown while there is a back button in it. Hosts that keep
    /// their own bar items in it leave the bar as it is.
    private let showsNavigationBarForBackOnly: Bool

    /// The step on screen, which follows the view model one update later so the page being left is
    /// redrawn with the new direction before it is removed.
    @State private var displayedStepIndex = 0

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.dismiss) private var dismiss

    init(
        onboardingServer: Server,
        steps: [OnboardingPermissionsNavigationViewModel.StepID]? = nil,
        showsNavigationBarForBackOnly: Bool = false,
        onDismiss: (() -> Void)? = nil
    ) {
        self
            ._viewModel =
            .init(wrappedValue: OnboardingPermissionsNavigationViewModel(
                onboardingServer: onboardingServer,
                steps: steps
            ))
        self.onboardingServer = onboardingServer
        self.showsNavigationBarForBackOnly = showsNavigationBarForBackOnly
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            ForEach(Array(viewModel.steps.enumerated()), id: \.element) { index, stepId in
                if index == displayedStepIndex {
                    stepView(for: stepId)
                        .transition(pushTransition(for: stepId))
                        .id(stepId)
                        .zIndex(Double(index))
                }
            }
        }
        .animation(DesignSystem.Animation.default, value: displayedStepIndex)
        .onChange(of: viewModel.currentStepIndex) { newValue in
            DispatchQueue.main.async {
                displayedStepIndex = newValue
            }
        }
        .toolbar {
            if showsBackButton {
                ToolbarItem(placement: .navigation) {
                    Button {
                        viewModel.previousStep()
                    } label: {
                        Label(L10n.Onboarding.Permissions.back, systemSymbol: .chevronBackward)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifier.onboardingHomeNetworkBack.rawValue)
                }
            }
        }
        .toolbar(navigationBarVisibility, for: .navigationBar)
    }

    private var navigationBarVisibility: Visibility {
        guard showsNavigationBarForBackOnly else { return .automatic }
        return showsBackButton ? .visible : .hidden
    }

    /// Follows the step on screen, so the bar changes together with the page instead of ahead of it.
    private var showsBackButton: Bool {
        viewModel.canGoBack(fromStepAt: displayedStepIndex)
    }

    @ViewBuilder
    private func stepView(for stepId: OnboardingPermissionsNavigationViewModel.StepID) -> some View {
        switch stepId {
        case .disclaimer:
            disclaimer
        case .location:
            location
        case .privacy:
            privacy
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

    private var privacy: some View {
        OnboardingPrivacyView { locationPrivacy, sensorPrivacy in
            viewModel.savePrivacyChoices(locationPrivacy: locationPrivacy, sensorPrivacy: sensorPrivacy)
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
                viewModel.requestLocationPermissionForLessSecureLocalConnection()
            }
        }
    }

    private var homeNetworkInput: some View {
        HomeNetworkInputView(onNext: { context in
            if context.networkName != nil || context.hardwareAddress != nil {
                viewModel.saveHomeNetwork(context)
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
                    finishFlow()
                }
            }
    }

    private var checkmarkSuccessView: some View {
        // View that display success animation and dismisses the flow shortly after
        CheckmarkDrawOnView()
            .onAppear {
                // Dismiss after a short delay to allow the user to see the success state
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    finishFlow()
                }
            }
    }

    private func navigateToCompletionScreen() {
        viewModel.nextStep()
    }

    private func finishFlow() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    // MARK: - Animation

    // Mimics UINavigationController push/pop animation

    private func pushTransition(for stepId: OnboardingPermissionsNavigationViewModel.StepID) -> AnyTransition {
        // Special handling for completion screen - always fade out
        if stepId == .completion {
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
