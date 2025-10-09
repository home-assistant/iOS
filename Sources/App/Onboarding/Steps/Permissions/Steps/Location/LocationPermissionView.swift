import Shared
import SwiftUI

struct LocationPermissionView: View {
    @StateObject private var viewModel = LocationPermissionViewModel()
    let completeAction: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: {
                Image(.Onboarding.world)
            },
            title: L10n.Onboarding.LocationAccess.title,
            primaryDescription: L10n.Onboarding.LocationAccess.primaryDescription,
            secondaryDescription: L10n.Onboarding.LocationAccess.secondaryDescription,
            primaryActionTitle: viewModel.showContinueButton ? L10n.continueLabel : L10n.Onboarding.LocationAccess.PrimaryAction.title,
            primaryAction: {
                if viewModel.showContinueButton {
                    completeAction()
                } else {
                    viewModel.requestLocationPermission()
                }
            },
            secondaryActionTitle: viewModel.showContinueButton ? nil :L10n.Onboarding.LocationAccess.SecondaryAction.title,
            secondaryAction: {
                if !viewModel.showContinueButton {
                    viewModel.disableLocationSensor()
                    completeAction()
                }
            }
        )
        .animation(.easeInOut(duration: 0.3), value: viewModel.showContinueButton)
        // Mimic navigation bar that is not present in this screen but is in the next
        .padding(.top, DesignSystem.Spaces.four)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    LocationPermissionView {}
}
