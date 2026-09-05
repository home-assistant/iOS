import SFSafeSymbols
import Shared
import SwiftUI

/// The permanent way into the migration from Settings, so a user who dismissed the launch prompt can
/// still find it. Renders nothing on the app taking over, or before the migration is configured.
struct AppMigrationSettingsSection: View {
    @ObservedObject private var presenter = AppMigrationPresenter.shared

    var body: some View {
        if AppMigrationConstants.isConfigured, AppMigrationRole.current == .source {
            Section {
                if AppMigrationStatus.isRetired {
                    row(
                        symbol: .checkmarkSealFill,
                        tint: .haPrimary,
                        title: L10n.AppMigration.Settings.Retired.title,
                        subtitle: L10n.AppMigration.Settings.Retired.subtitle
                    )
                } else {
                    Button {
                        presenter.presentExportFlow()
                    } label: {
                        row(
                            symbol: .arrowRightCircleFill,
                            tint: .haPrimary,
                            title: L10n.AppMigration.Settings.title,
                            subtitle: L10n.AppMigration.Settings.subtitle
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func row(symbol: SFSymbol, tint: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: symbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .foregroundStyle(tint)
                .padding(.top, DesignSystem.Spaces.half)
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text(title)
                Text(subtitle)
                    .font(DesignSystem.Font.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    List {
        AppMigrationSettingsSection()
    }
}
