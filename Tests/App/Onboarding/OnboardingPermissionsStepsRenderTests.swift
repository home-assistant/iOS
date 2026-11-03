@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Renders every permission step the onboarding flow can show on its own, in both layout
/// directions, and walks a multi-step flow forward and back.
@Suite(.sharedState)
@MainActor
struct OnboardingPermissionsStepsRenderTests {
    private func render(
        steps: [OnboardingPermissionsNavigationViewModel.StepID],
        layoutDirection: LayoutDirection = .leftToRight,
        drive: ((OnboardingPermissionsNavigationViewModel) -> Void)? = nil
    ) async {
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: .fake(), steps: steps)
        let controller = UIHostingController(
            rootView: NavigationStack {
                OnboardingPermissionsNavigationView(
                    onboardingServer: .fake(),
                    showsNavigationBarForBackOnly: true,
                    viewModel: viewModel,
                    onDismiss: {}
                )
            }
            .environment(\.layoutDirection, layoutDirection)
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()
        if let drive {
            drive(viewModel)
            for _ in 0 ..< 5 {
                await Task.yield()
            }
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }
        window.isHidden = true
        window.rootViewController = nil
    }

    @Test(arguments: OnboardingPermissionsNavigationViewModel.StepID.allCases)
    func rendersEachStepOnItsOwn(step: OnboardingPermissionsNavigationViewModel.StepID) async {
        await render(steps: [step])
    }

    @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
    func walksAFlowForwardAndBack(layoutDirection: LayoutDirection) async {
        await render(
            steps: [.disclaimer, .localAccess, .homeNetwork, .completion],
            layoutDirection: layoutDirection
        ) { viewModel in
            viewModel.nextStep()
            viewModel.nextStep()
            viewModel.previousStep()
        }
    }
}
