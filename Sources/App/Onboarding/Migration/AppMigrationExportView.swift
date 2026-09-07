import SFSafeSymbols
import Shared
import SwiftUI

/// The previous app's side of the handoff: confirm and package the setup, then stay as the only screen
/// until the user has checked the new app and erased this one.
struct AppMigrationExportView: View {
    let state: AppMigrationExportState
    let summary: AppMigrationSummary
    let transferAction: () -> Void
    let openNewAppAction: () -> Void
    let transferAgainAction: () -> Void
    let eraseAction: () -> Void
    let cancelAction: () -> Void

    @State private var showsEraseConfirmation = false
    @State private var showsTransferAgainConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spaces.three) {
                MaterialDesignIconsImage(icon: headerIcon, size: 96)
                    .foregroundStyle(headerTint)
                    .padding(.top, DesignSystem.Spaces.two)
                Text(title)
                    .font(DesignSystem.Font.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spaces.two)
                VStack(spacing: DesignSystem.Spaces.two) {
                    Text(message)
                        .font(DesignSystem.Font.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if case let .failed(failure) = state {
                        HAAlertView(title: L10n.AppMigration.Export.Failed.title, alertType: .error) {
                            Text(failure)
                        } action: {
                            EmptyView()
                        }
                    }
                    if showsInventory {
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                            Label(L10n.AppMigration.Export.Section.includes, systemSymbol: .checkmarkCircleFill)
                                .font(DesignSystem.Font.headline)
                                .foregroundStyle(.haSuccessColor)
                            CardView {
                                VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                                    ForEach(AppMigrationTransferredItem.allCases) { item in
                                        AppMigrationItemRow(
                                            icon: item.icon,
                                            tint: .haSuccessColor,
                                            title: item.title,
                                            caption: item == .servers ? summary.serversDescription : item.explanation
                                        )
                                    }
                                }
                                .padding(DesignSystem.Spaces.one)
                            }
                        }
                        .padding(.top, DesignSystem.Spaces.two)
                    }
                }
                .padding(.horizontal, DesignSystem.Spaces.two)
                Spacer(minLength: DesignSystem.Spaces.four)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .frame(maxWidth: Sizes.maxWidthForLargerScreens)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DesignSystem.Spaces.one) {
                switch state {
                case .handedOff:
                    Button(action: openNewAppAction) {
                        Text(L10n.AppMigration.Export.HandedOff.openButton)
                    }
                    .buttonStyle(.primaryButton)
                    .accessibilityIdentifier(AccessibilityIdentifier.migrationExportOpenNewApp.rawValue)
                    Button(L10n.AppMigration.Export.HandedOff.transferAgainButton) {
                        showsTransferAgainConfirmation = true
                    }
                    .buttonStyle(.secondaryButton)
                    .tint(Color.haPrimary)
                    .accessibilityIdentifier(AccessibilityIdentifier.migrationExportTransferAgain.rawValue)
                    .confirmationDialog(
                        L10n.AppMigration.Export.TransferAgainConfirmation.title,
                        isPresented: $showsTransferAgainConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button(
                            L10n.AppMigration.Export.TransferAgainConfirmation.confirmButton,
                            action: transferAgainAction
                        )
                    } message: {
                        Text(L10n.AppMigration.Export.TransferAgainConfirmation.body)
                    }
                    Button(L10n.AppMigration.Export.HandedOff.eraseButton) {
                        showsEraseConfirmation = true
                    }
                    .buttonStyle(.secondaryNegativeButton)
                    .accessibilityIdentifier(AccessibilityIdentifier.migrationExportErase.rawValue)
                    .confirmationDialog(
                        L10n.AppMigration.Export.EraseConfirmation.title,
                        isPresented: $showsEraseConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button(
                            L10n.AppMigration.Export.EraseConfirmation.confirmButton,
                            role: .destructive,
                            action: eraseAction
                        )
                    } message: {
                        Text(L10n.AppMigration.Export.EraseConfirmation.body)
                    }
                case .erased:
                    Button(action: openNewAppAction) {
                        Text(L10n.AppMigration.Export.HandedOff.openButton)
                    }
                    .buttonStyle(.primaryButton)
                    .accessibilityIdentifier(AccessibilityIdentifier.migrationExportOpenNewApp.rawValue)
                case .idle, .preparing, .failed:
                    HAProgressButton(
                        state == .preparing ? L10n.AppMigration.Export.Preparing.title : L10n.AppMigration.Export
                            .transferButton,
                        icon: .transferIcon,
                        state: progressButtonState,
                        action: transferAction
                    )
                    .accessibilityIdentifier(AccessibilityIdentifier.migrationExportTransfer.rawValue)
                    .disabled(state == .preparing)
                    Button(action: cancelAction) {
                        Text(L10n.AppMigration.Export.cancelButton)
                    }
                    .buttonStyle(.secondaryButton)
                    .tint(Color.haPrimary)
                    .disabled(state == .preparing)
                }
            }
            .padding(.bottom, Current.isCatalyst ? DesignSystem.Spaces.two : DesignSystem.Spaces.one)
            .frame(maxWidth: Sizes.maxWidthForLargerScreens)
            .padding([.horizontal, .top], DesignSystem.Spaces.two)
            .background(Color(uiColor: .systemBackground).opacity(0.95))
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var showsInventory: Bool {
        switch state {
        case .idle, .preparing, .failed: true
        case .handedOff, .erased: false
        }
    }

    private var headerIcon: MaterialDesignIcons {
        switch state {
        case .idle, .preparing, .failed: .transferIcon
        case .handedOff: .checkCircleOutlineIcon
        case .erased: .cellphoneRemoveIcon
        }
    }

    private var headerTint: Color {
        switch state {
        case .idle, .preparing, .failed: .haPrimary
        case .handedOff: .haSuccessColor
        case .erased: .secondary
        }
    }

    private var title: String {
        switch state {
        case .idle, .preparing, .failed: L10n.AppMigration.Export.title
        case .handedOff: L10n.AppMigration.Export.HandedOff.title
        case .erased: L10n.AppMigration.Export.Erased.title
        }
    }

    private var message: String {
        switch state {
        case .idle, .preparing, .failed: L10n.AppMigration.Export.body
        case .handedOff: L10n.AppMigration.Export.HandedOff.checkBody
        case .erased: L10n.AppMigration.Export.Erased.body
        }
    }

    private var progressButtonState: HAProgressButtonState {
        switch state {
        case .idle, .handedOff, .erased: .idle
        case .preparing: .inProgress
        case .failed: .failure
        }
    }
}

#Preview("Ready") {
    AppMigrationExportView(
        state: .idle,
        summary: .preview,
        transferAction: {},
        openNewAppAction: {},
        transferAgainAction: {},
        eraseAction: {},
        cancelAction: {}
    )
}

#Preview("Handed off") {
    AppMigrationExportView(
        state: .handedOff,
        summary: .preview,
        transferAction: {},
        openNewAppAction: {},
        transferAgainAction: {},
        eraseAction: {},
        cancelAction: {}
    )
}

#Preview("Erased") {
    AppMigrationExportView(
        state: .erased,
        summary: .preview,
        transferAction: {},
        openNewAppAction: {},
        transferAgainAction: {},
        eraseAction: {},
        cancelAction: {}
    )
}

#Preview("Failed") {
    AppMigrationExportView(
        state: .failed(message: "The new app is not installed on this device."),
        summary: .preview,
        transferAction: {},
        openNewAppAction: {},
        transferAgainAction: {},
        eraseAction: {},
        cancelAction: {}
    )
}
