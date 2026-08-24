import SFSafeSymbols
import Shared
import SwiftUI

/// Explains the move to the new app before anything happens: what travels, what has to be set up
/// again, and that the old app stands down afterwards.
///
/// A grouped `List`, so the two disclosures are real sections with real headers and separators
/// rather than a hand-built imitation. Only the header row opts out of list styling.
struct AppMigrationIntroView: View {
    let serverCount: Int
    let onStart: () -> Void
    let onLater: () -> Void

    var body: some View {
        List {
            AppMigrationHeaderRow(
                symbol: .arrowUpForwardApp,
                title: L10n.AppMigration.Intro.title,
                primaryDescription: L10n.AppMigration.Intro.primaryDescription,
                secondaryDescription: L10n.AppMigration.Intro.secondaryDescription
            )
            .appMigrationHeaderRowStyle()

            Section(L10n.AppMigration.Intro.Included.header) {
                rows(
                    symbol: .checkmarkCircleFill,
                    tint: .green,
                    lines: [
                        L10n.AppMigration.Intro.Included.servers(serverCount),
                        L10n.AppMigration.Intro.Included.configuration,
                        L10n.AppMigration.Intro.Included.settings,
                    ]
                )
            }

            Section(L10n.AppMigration.Intro.Excluded.header) {
                rows(
                    symbol: .arrowClockwise,
                    tint: .secondary,
                    lines: [
                        L10n.AppMigration.Intro.Excluded.widgets,
                        L10n.AppMigration.Intro.Excluded.complications,
                        L10n.AppMigration.Intro.Excluded.shortcuts,
                    ]
                )
            }
        }
        .listTopContentMargin()
        .safeAreaInset(edge: .bottom) {
            AppMigrationBottomActions(
                primaryTitle: L10n.AppMigration.Intro.startButton,
                primaryAction: onStart,
                secondaryTitle: L10n.AppMigration.Intro.laterButton,
                secondaryAction: onLater
            )
        }
    }

    private func rows(symbol: SFSymbol, tint: Color, lines: [String]) -> some View {
        ForEach(lines, id: \.self) { line in
            AppMigrationDisclosureRow(symbol: symbol, tint: tint, text: line)
        }
    }
}

#Preview {
    AppMigrationIntroView(serverCount: 3, onStart: {}, onLater: {})
}
