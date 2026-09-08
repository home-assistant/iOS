import Shared
import SwiftUI

/// Shown in the new app once the previous app's setup has been applied.
struct AppMigrationCompleteView: View {
    static let checkmarkSize: CGFloat = 96

    let summary: AppMigrationSummary
    /// While the checkmark is still gliding in from `AppMigrationSuccessView`, the illustration slot
    /// only marks where it lands; once settled the checkmark is drawn here for good.
    var checkmarkNamespace: Namespace.ID?
    var checkmarkSettled = true
    let continueAction: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: {
                if let checkmarkNamespace, !checkmarkSettled {
                    Color.clear
                        .frame(width: Self.checkmarkSize, height: Self.checkmarkSize)
                        .matchedGeometryEffect(id: AppMigrationSuccessView.checkmarkID, in: checkmarkNamespace)
                        .padding(.top, DesignSystem.Spaces.two)
                } else {
                    CheckmarkDrawOnView(size: Self.checkmarkSize, tint: .haSuccessColor, animated: false)
                        .padding(.top, DesignSystem.Spaces.two)
                }
            },
            title: L10n.AppMigration.Complete.title,
            primaryDescription: summary.completionBody,
            secondaryDescription: summary.serverCount == 0 ? nil : summary.serversDescription,
            content: {
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                    HASectionPill(L10n.AppMigration.Complete.Section.nextSteps)
                    CardView(cornerRadius: DesignSystem.CornerRadius.two) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                            ForEach(AppMigrationFollowUpItem.allCases) { item in
                                AppMigrationItemRow(
                                    icon: item.icon,
                                    tint: .secondary,
                                    title: item.title,
                                    caption: item.explanation
                                )
                            }
                        }
                    }
                }
                .padding(.top, DesignSystem.Spaces.two)
            },
            primaryActionTitle: L10n.AppMigration.Complete.continueButton,
            primaryAction: {
                AppMigrationHaptics.tap()
                continueAction()
            },
            primaryActionIdentifier: AccessibilityIdentifier.migrationCompleteContinue.rawValue
        )
    }
}

#Preview {
    AppMigrationCompleteView(summary: .preview, continueAction: {})
}
