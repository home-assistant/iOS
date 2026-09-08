import SFSafeSymbols
import Shared
import SwiftUI

/// What comes along in the transfer (green) and what the user sets up again afterwards (gray).
struct AppMigrationOverviewView: View {
    let startAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.oneAndHalf) {
                Text(L10n.AppMigration.Overview.title)
                    .font(DesignSystem.Font.title.bold())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, DesignSystem.Spaces.half)

                HASectionPill(
                    L10n.AppMigration.Overview.Section.moves,
                    icon: .checkmarkCircleFill,
                    tint: .haSuccessColor
                )
                CardView(cornerRadius: DesignSystem.CornerRadius.two) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                        ForEach(AppMigrationTransferredItem.allCases) { item in
                            AppMigrationItemRow(
                                icon: item.icon,
                                tint: .haSuccessColor,
                                title: item.title,
                                caption: item.explanation
                            )
                        }
                    }
                }

                HASectionPill(L10n.AppMigration.Overview.Section.followUp, icon: .arrowUturnBackwardCircleFill)
                    .padding(.top, DesignSystem.Spaces.half)
                CardView(cornerRadius: DesignSystem.CornerRadius.two) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                        ForEach(AppMigrationFollowUpItem.beforeTransfer) { item in
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
            .padding(.horizontal, DesignSystem.Spaces.two)
            .padding(.top, DesignSystem.Spaces.one)
            .frame(maxWidth: Sizes.maxWidthForLargerScreens)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            Button(action: startAction) {
                Text(L10n.AppMigration.Overview.startButton)
            }
            .buttonStyle(.primaryButton)
            .accessibilityIdentifier(AccessibilityIdentifier.migrationOverviewStart.rawValue)
            .padding(.bottom, Current.isCatalyst ? DesignSystem.Spaces.two : DesignSystem.Spaces.one)
            .frame(maxWidth: Sizes.maxWidthForLargerScreens)
            .padding([.horizontal, .top], DesignSystem.Spaces.two)
            .background(Color(uiColor: .systemBackground).opacity(0.95))
        }
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview {
    AppMigrationOverviewView(startAction: {})
}
