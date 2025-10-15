import Shared
import SwiftUI

struct LocalAccessOnlyDisclaimerView: View {
    let onContinue: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: {
                Image(.Onboarding.rocket)
            },
            title: L10n.Onboarding.LocalOnlyDisclaimer.title,
            primaryDescription: L10n.Onboarding.LocalOnlyDisclaimer.primaryDescription,
            primaryActionTitle: L10n.Onboarding.LocalOnlyDisclaimer.PrimaryButton.title,
            primaryAction: {
                onContinue()
            }
        )
    }
}

#Preview {
    LocalAccessOnlyDisclaimerView {
        // Continue action preview
    }
}
