import SFSafeSymbols
import Shared
import SwiftUI

/// The previous app's side of the handoff: confirm, package the setup and pass it to the new app.
struct AppMigrationExportView: View {
    let state: AppMigrationExportState
    let summary: AppMigrationSummary
    let transferAction: () -> Void
    let openNewAppAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spaces.three) {
                MaterialDesignIconsImage(icon: state == .handedOff ? .checkCircleOutlineIcon : .transferIcon, size: 96)
                    .foregroundStyle(state == .handedOff ? .haSuccessColor : .haPrimary)
                    .padding(.top, DesignSystem.Spaces.two)
                Text(state == .handedOff ? L10n.AppMigration.Export.HandedOff.title : L10n.AppMigration.Export.title)
                    .font(DesignSystem.Font.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spaces.two)
                VStack(spacing: DesignSystem.Spaces.two) {
                    Text(state == .handedOff ? L10n.AppMigration.Export.HandedOff.body : L10n.AppMigration.Export.body)
                        .font(DesignSystem.Font.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if case let .failed(message) = state {
                        HAAlertView(title: L10n.AppMigration.Export.Failed.title, alertType: .error) {
                            Text(message)
                        } action: {
                            EmptyView()
                        }
                    }
                    if state != .handedOff {
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
                if state == .handedOff {
                    Button(action: openNewAppAction) {
                        Text(L10n.AppMigration.Export.HandedOff.openButton)
                    }
                    .buttonStyle(.primaryButton)
                } else {
                    HAProgressButton(
                        state == .preparing ? L10n.AppMigration.Export.Preparing.title : L10n.AppMigration.Export
                            .transferButton,
                        icon: .transferIcon,
                        state: progressButtonState,
                        action: transferAction
                    )
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

    private var progressButtonState: HAProgressButtonState {
        switch state {
        case .idle, .handedOff: .idle
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
        cancelAction: {}
    )
}

#Preview("Preparing") {
    AppMigrationExportView(
        state: .preparing,
        summary: .preview,
        transferAction: {},
        openNewAppAction: {},
        cancelAction: {}
    )
}

#Preview("Handed off") {
    AppMigrationExportView(
        state: .handedOff,
        summary: .preview,
        transferAction: {},
        openNewAppAction: {},
        cancelAction: {}
    )
}

#Preview("Failed") {
    AppMigrationExportView(
        state: .failed(message: "The new app is not installed on this device."),
        summary: .preview,
        transferAction: {},
        openNewAppAction: {},
        cancelAction: {}
    )
}
