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

                Label(L10n.AppMigration.Overview.Section.moves, systemSymbol: .checkmarkCircleFill)
                    .font(DesignSystem.Font.headline)
                    .foregroundStyle(.haSuccessColor)
                CardView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                        ForEach(AppMigrationTransferredItem.allCases) { item in
                            AppMigrationItemRow(
                                icon: item.icon,
                                tint: .haSuccessColor,
                                title: item.title,
                                caption: item.explanation
                            )
                        }
                    }
                    .padding(DesignSystem.Spaces.one)
                }

                Label(L10n.AppMigration.Overview.Section.followUp, systemSymbol: .arrowUturnBackwardCircleFill)
                    .font(DesignSystem.Font.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, DesignSystem.Spaces.half)
                CardView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                        ForEach(AppMigrationFollowUpItem.beforeTransfer) { item in
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
