import SFSafeSymbols
import Shared
import SwiftUI

/// Explains the move to the new app before anything happens: what travels, what has to be set up
/// again, and that the old app stands down afterwards.
struct AppMigrationIntroView: View {
    let serverCount: Int
    let onStart: () -> Void
    let onLater: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: { AppMigrationIllustration(symbol: .arrowUpForwardApp) },
            title: L10n.AppMigration.Intro.title,
            primaryDescription: L10n.AppMigration.Intro.primaryDescription,
            secondaryDescription: L10n.AppMigration.Intro.secondaryDescription,
            content: { disclosure },
            primaryActionTitle: L10n.AppMigration.Intro.startButton,
            primaryAction: onStart,
            secondaryActionTitle: L10n.AppMigration.Intro.laterButton,
            secondaryAction: onLater
        )
    }

    private var disclosure: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
            group(
                header: L10n.AppMigration.Intro.Included.header,
                tint: .haPrimary,
                symbol: .checkmarkCircleFill,
                lines: [
                    L10n.AppMigration.Intro.Included.servers(serverCount),
                    L10n.AppMigration.Intro.Included.configuration,
                    L10n.AppMigration.Intro.Included.settings,
                ]
            )
            group(
                header: L10n.AppMigration.Intro.Excluded.header,
                tint: .secondary,
                symbol: .arrowClockwise,
                lines: [
                    L10n.AppMigration.Intro.Excluded.widgets,
                    L10n.AppMigration.Intro.Excluded.complications,
                    L10n.AppMigration.Intro.Excluded.shortcuts,
                ]
            )
        }
        .frame(maxWidth: DesignSystem.List.rowMaxWidth, alignment: .leading)
    }

    private func group(header: String, tint: Color, symbol: SFSymbol, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            Text(header)
                .font(DesignSystem.Font.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            AppMigrationRowGroup(items: lines) { line in
                AppMigrationDisclosureRow(symbol: symbol, tint: tint, text: line)
            }
        }
    }
}

#Preview {
    AppMigrationIntroView(serverCount: 3, onStart: {}, onLater: {})
}
