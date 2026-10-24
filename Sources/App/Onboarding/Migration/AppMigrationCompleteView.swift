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
    /// Set once the previous app reports it wiped itself.
    var previousAppErased = false
    /// Asks the previous app to wipe itself; absent when it is not installed any more.
    var eraseAction: (() -> Void)?
    let continueAction: () -> Void

    /// Set when the user chose to keep the previous app for now; the next steps show from then on.
    @State private var keepsPreviousApp = false

    /// Erasing the previous app comes first; the next steps only once it is gone, kept on purpose, or
    /// not installed.
    private var showsNextSteps: Bool {
        previousAppErased || keepsPreviousApp || eraseAction == nil
    }

    private var offersErase: Bool {
        eraseAction != nil && !previousAppErased
    }

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
                if previousAppErased {
                    HAAlertView(title: L10n.AppMigration.Complete.Erased.title, alertType: .success) {
                        Text(L10n.AppMigration.Complete.Erased.body)
                    } action: {
                        EmptyView()
                    }
                    .padding(.top, DesignSystem.Spaces.two)
                }
                if showsNextSteps {
                    nextSteps
                }
            },
            primaryActionTitle: showsNextSteps ? L10n.AppMigration.Complete.continueButton : L10n.AppMigration.Complete
                .eraseButton,
            primaryAction: primaryTapped,
            primaryActionIdentifier: showsNextSteps
                ? AccessibilityIdentifier.migrationCompleteContinue.rawValue
                : AccessibilityIdentifier.migrationCompleteErase.rawValue,
            secondaryActionTitle: secondaryActionTitle,
            secondaryAction: secondaryTapped,
            secondaryActionIdentifier: showsNextSteps
                ? AccessibilityIdentifier.migrationCompleteErase.rawValue
                : AccessibilityIdentifier.migrationCompleteKeep.rawValue
        )
    }

    func primaryTapped() {
        if showsNextSteps {
            AppMigrationHaptics.tap()
            continueAction()
        } else {
            AppMigrationHaptics.warning()
            eraseAction?()
        }
    }

    func secondaryTapped() {
        if showsNextSteps {
            AppMigrationHaptics.warning()
            eraseAction?()
        } else {
            AppMigrationHaptics.tap()
            withAnimation(DesignSystem.Animation.default) {
                keepsPreviousApp = true
            }
        }
    }

    private var secondaryActionTitle: String? {
        if showsNextSteps {
            return offersErase ? L10n.AppMigration.Complete.eraseButton : nil
        }
        return L10n.AppMigration.Complete.keepPreviousAppButton
    }

    private var nextSteps: some View {
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
    }
}

#Preview {
    AppMigrationCompleteView(summary: .preview, eraseAction: {}, continueAction: {})
}

#Preview("Previous app erased") {
    AppMigrationCompleteView(summary: .preview, previousAppErased: true, eraseAction: {}, continueAction: {})
}
