import Shared
import SwiftUI

/// Hosts the permission steps in their own `NavigationStack` for flows presented over the web view
/// (forced security-level decisions, connection preference updates). Each step pushes the next one
/// itself (see `OnboardingPermissionsStepView`), so this view only needs to render the first step.
///
/// During onboarding the steps are instead pushed onto the onboarding stack directly (no wrapping
/// `NavigationStack`) — see `OnboardingServersListView`.
struct OnboardingPermissionsNavigationView: View {
    @StateObject private var viewModel: OnboardingPermissionsNavigationViewModel

    @Environment(\.dismiss) private var dismiss

    private let onDismiss: (() -> Void)?
    private let showsCloseButton: Bool

    init(
        onboardingServer: Server,
        steps: [OnboardingPermissionsNavigationViewModel.StepID]? = nil,
        onDismiss: (() -> Void)? = nil,
        showsCloseButton: Bool = false
    ) {
        self
            ._viewModel =
            .init(wrappedValue: OnboardingPermissionsNavigationViewModel(
                onboardingServer: onboardingServer,
                steps: steps
            ))
        self.onDismiss = onDismiss
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        NavigationStack {
            rootStep
        }
        .onAppear {
            viewModel.finish = { finishFlow() }
        }
    }

    @ViewBuilder
    private var rootStep: some View {
        if let firstStep = viewModel.steps.first {
            OnboardingPermissionsStepView(step: firstStep, viewModel: viewModel)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if showsCloseButton {
                            CloseButton {
                                finishFlow()
                            }
                        }
                    }
                }
        }
    }

    private func finishFlow() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
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
