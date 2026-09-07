import Shared
import SwiftUI

/// First screen of the transfer in the new app: what moves over, what needs a hand afterwards.
struct AppMigrationIntroView: View {
    let startAction: () -> Void
    let skipAction: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: {
                MaterialDesignIconsImage(icon: .transferIcon, size: 96)
                    .foregroundStyle(.haPrimary)
            },
            title: L10n.AppMigration.Intro.title,
            primaryDescription: L10n.AppMigration.Intro.body,
            content: {
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                    HASectionTitle(L10n.AppMigration.Intro.Section.moves)
                    CardView {
                        VStack(spacing: .zero) {
                            ForEach(AppMigrationTransferredItem.allCases) { item in
                                HASettingsRow(heading: item.title, description: item.explanation) {
                                    MaterialDesignIconsImage(icon: item.icon, size: 24)
                                        .foregroundStyle(.haPrimary)
                                } content: {
                                    EmptyView()
                                }
                            }
                        }
                    }
                    HASectionTitle(L10n.AppMigration.Intro.Section.followUp)
                    CardView {
                        VStack(spacing: .zero) {
                            ForEach(AppMigrationFollowUpItem.beforeTransfer) { item in
                                HASettingsRow(heading: item.title, description: item.explanation) {
                                    MaterialDesignIconsImage(icon: item.icon, size: 24)
                                        .foregroundStyle(.secondary)
                                } content: {
                                    EmptyView()
                                }
                            }
                        }
                    }
                }
                .padding(.top, DesignSystem.Spaces.two)
            },
            primaryActionTitle: L10n.AppMigration.Intro.startButton,
            primaryAction: startAction,
            secondaryActionTitle: L10n.AppMigration.Intro.skipButton,
            secondaryAction: skipAction
        )
    }
}

#Preview {
    AppMigrationIntroView(startAction: {}, skipAction: {})
}
