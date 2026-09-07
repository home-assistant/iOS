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
            primaryDescription: L10n.AppMigration.Complete.body,
            secondaryDescription: summary.serversDescription,
            content: {
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                    HASectionTitle(L10n.AppMigration.Complete.Section.nextSteps)
                    CardView {
                        VStack(spacing: .zero) {
                            ForEach(AppMigrationFollowUpItem.allCases) { item in
                                HASettingsRow(heading: item.title, description: item.explanation) {
                                    MaterialDesignIconsImage(icon: item.icon, size: 24)
                                        .foregroundStyle(.haPrimary)
                                } content: {
                                    EmptyView()
                                }
                            }
                        }
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
