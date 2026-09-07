import Shared
import SwiftUI

/// Shown in the new app once the previous app's setup has been applied.
struct AppMigrationCompleteView: View {
    let summary: AppMigrationSummary
    let continueAction: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: {
                MaterialDesignIconsImage(icon: .checkCircleOutlineIcon, size: 96)
                    .foregroundStyle(.haSuccessColor)
            },
            title: L10n.AppMigration.Complete.title,
            primaryDescription: summary.completionBody,
            secondaryDescription: summary.serverCount == 0 ? nil : summary.serversDescription,
            content: {
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                    HASectionTitle(L10n.AppMigration.Complete.Section.nextSteps)
                    CardView {
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                            ForEach(AppMigrationFollowUpItem.allCases) { item in
                                AppMigrationItemRow(
                                    icon: item.icon,
                                    tint: .secondary,
                                    title: item.title,
                                    caption: item.explanation
                                )
                            }
                        }
                        .padding(DesignSystem.Spaces.one)
                    }
                }
                .padding(.top, DesignSystem.Spaces.two)
            },
            primaryActionTitle: L10n.AppMigration.Complete.continueButton,
            primaryAction: continueAction
        )
    }
}

#Preview {
    AppMigrationCompleteView(summary: .preview, continueAction: {})
}
