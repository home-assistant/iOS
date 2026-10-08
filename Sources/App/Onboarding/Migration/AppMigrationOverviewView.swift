import SFSafeSymbols
import Shared
import SwiftUI

/// What comes along in the transfer (green) and what the user sets up again afterwards (gray). The
/// same screen on both sides: the new app starts the transfer from it, the previous app confirms it.
struct AppMigrationOverviewView: View {
    enum Actions {
        /// New app: ask the previous app for the setup.
        case startTransfer(() -> Void)
        /// Previous app: package the setup, or leave it for later.
        case transfer(state: HAProgressButtonState, transfer: () -> Void, later: () -> Void)
    }

    /// A line under the title; the previous app says who is asking.
    var subtitle: String?
    /// Replaces the generic servers caption with the real count.
    var serversCaption: String?
    /// Why the last attempt did not go through, shown above the lists.
    var failure: String?
    let actions: Actions

    init(startAction: @escaping () -> Void) {
        self.init(actions: .startTransfer(startAction))
    }

    init(subtitle: String? = nil, serversCaption: String? = nil, failure: String? = nil, actions: Actions) {
        self.subtitle = subtitle
        self.serversCaption = serversCaption
        self.failure = failure
        self.actions = actions
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.oneAndHalf) {
                Text(L10n.AppMigration.Overview.title)
                    .font(DesignSystem.Font.title.bold())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, subtitle == nil ? DesignSystem.Spaces.half : 0)

                if let subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Font.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, DesignSystem.Spaces.half)
                }

                if let failure {
                    HAAlertView(title: L10n.AppMigration.Export.Failed.title, alertType: .error) {
                        Text(failure)
                    } action: {
                        EmptyView()
                    }
                }

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
                                caption: item == .servers ? serversCaption ?? item.explanation : item.explanation
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
            VStack(spacing: DesignSystem.Spaces.one) {
                switch actions {
                case let .startTransfer(start):
                    Button(action: start) {
                        Text(L10n.AppMigration.Overview.startButton)
                    }
                    .buttonStyle(.primaryButton)
                    .accessibilityIdentifier(AccessibilityIdentifier.migrationOverviewStart.rawValue)
                case let .transfer(state, transfer, later):
                    HAProgressButton(
                        L10n.AppMigration.Export.transferButton,
                        icon: .transferIcon,
                        state: state,
                        action: {
                            AppMigrationHaptics.tap()
                            transfer()
                        }
                    )
                    .accessibilityIdentifier(AccessibilityIdentifier.migrationExportTransfer.rawValue)
                    Button {
                        AppMigrationHaptics.tap()
                        later()
                    } label: {
                        Text(L10n.AppMigration.Export.laterButton)
                    }
                    .buttonStyle(.secondaryButton)
                    .tint(Color.haPrimary)
                }
            }
            .padding(.bottom, Current.isCatalyst ? DesignSystem.Spaces.two : DesignSystem.Spaces.one)
            .frame(maxWidth: Sizes.maxWidthForLargerScreens)
            .padding([.horizontal, .top], DesignSystem.Spaces.two)
            .background(Color(uiColor: .systemBackground).opacity(0.95))
        }
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview("New app") {
    AppMigrationOverviewView(startAction: {})
}

#Preview("Previous app") {
    AppMigrationOverviewView(
        subtitle: L10n.AppMigration.Export.body,
        serversCaption: AppMigrationSummary.preview.serversDescription,
        actions: .transfer(state: .idle, transfer: {}, later: {})
    )
}
