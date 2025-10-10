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
            primaryActionTitle: L10n.Onboarding.LocationAccess.PrimaryAction.title,
            primaryAction: {
                    viewModel.requestLocationPermission()
            },
            secondaryActionTitle: L10n.Onboarding.LocationAccess.SecondaryAction.title,
            secondaryAction: {
                    viewModel.disableLocationSensor()
                    completeAction()
            }
        )
        // Mimic navigation bar that is not present in this screen but is in the next
        .padding(.top, DesignSystem.Spaces.four)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.shouldComplete) { shouldComplete in
            if shouldComplete {
                completeAction()
            }
        }
    }
}

#Preview {
    LocationPermissionView {}
}
