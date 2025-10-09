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
            title: "Use this device's location for automations",
            primaryDescription: "Location sharing enables powerful automations, such as turning off the heating when you leave home. This option shares the device’s location only with your Home Assistant system.",
            secondaryDescription: "This data stays in your home and is never sent to third parties. It also helps strengthen the security of your connection to Home Assistant.",
            primaryActionTitle: "Share my location",
            primaryAction: {
                viewModel.requestLocationPermission()
            },
            secondaryActionTitle: "Do not share my location",
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
    LocationPermissionView() {}
}
