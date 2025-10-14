import Shared
import SwiftUI

struct LocationPermissionView: View {
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

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
                primaryAction()
            },
            secondaryActionTitle: L10n.Onboarding.LocationAccess.SecondaryAction.title,
            secondaryAction: {
                secondaryAction()
            }
        )
    }
}

#Preview {
    LocationPermissionView {} secondaryAction: {}
}
