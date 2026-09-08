import SFSafeSymbols
import Shared
import SwiftUI

/// Shown after the transfer: the permissions the previous app held, each to be allowed again here.
struct AppMigrationPermissionsView: View {
    @StateObject private var viewModel: AppMigrationPermissionsViewModel
    @Environment(\.scenePhase) private var scenePhase
    let continueAction: () -> Void

    init(permissions: [SensorPermission], continueAction: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: AppMigrationPermissionsViewModel(permissions: permissions))
        self.continueAction = continueAction
    }

    var body: some View {
        BaseOnboardingView(
            illustration: {
                MaterialDesignIconsImage(icon: .shieldCheckOutlineIcon, size: 96)
                    .foregroundStyle(.haPrimary)
            },
            title: L10n.AppMigration.Permissions.title,
            primaryDescription: L10n.AppMigration.Permissions.body,
            content: {
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                    HASectionTitle(L10n.AppMigration.Permissions.Section.previousApp)
                    CardView {
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                            ForEach(viewModel.permissions) { permission in
                                let status = viewModel.status(for: permission)
                                Button {
                                    viewModel.handleTap(on: permission)
                                } label: {
                                    HStack(alignment: .center, spacing: DesignSystem.Spaces.oneAndHalf) {
                                        Image(uiImage: permission.icon.image(
                                            ofSize: CGSize(width: 24, height: 24),
                                            color: .haPrimary
                                        ))
                                        .frame(width: 24, height: 24)
                                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                                            Text(permission.title)
                                                .font(DesignSystem.Font.body)
                                                .foregroundStyle(.primary)
                                            Text(status.description)
                                                .font(DesignSystem.Font.footnote)
                                                .foregroundStyle(status.color)
                                        }
                                        .fixedSize(horizontal: false, vertical: true)
                                        Spacer(minLength: .zero)
                                        switch status {
                                        case .granted, .authorizedAlways, .authorizedWhenInUse:
                                            Image(systemSymbol: .checkmarkCircleFill)
                                                .foregroundStyle(.haSuccessColor)
                                        case .denied, .restricted:
                                            Text(L10n.AppMigration.Permissions.settingsButton)
                                                .font(DesignSystem.Font.callout.weight(.semibold))
                                                .foregroundStyle(.haPrimary)
                                        case .notDetermined, .unknown:
                                            Text(L10n.AppMigration.Permissions.allowButton)
                                                .font(DesignSystem.Font.callout.weight(.semibold))
                                                .foregroundStyle(.haPrimary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(DesignSystem.Spaces.one)
                    }
                }
                .padding(.top, DesignSystem.Spaces.two)
            },
            primaryActionTitle: viewModel.isSettled
                ? L10n.AppMigration.Permissions.continueButton
                : L10n.AppMigration.Permissions.allowAllButton,
            primaryAction: viewModel.isSettled ? continueAction : viewModel.allowAll,
            primaryActionIdentifier: AccessibilityIdentifier.migrationPermissionsPrimary.rawValue,
            secondaryActionTitle: viewModel.isSettled ? nil : L10n.AppMigration.Permissions.skipButton,
            secondaryAction: viewModel.isSettled ? nil : continueAction,
            secondaryActionIdentifier: AccessibilityIdentifier.migrationPermissionsSkip.rawValue
        )
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                viewModel.refresh()
            }
        }
    }
}

#Preview {
    AppMigrationPermissionsView(permissions: [.location, .notification, .motion, .camera], continueAction: {})
}
