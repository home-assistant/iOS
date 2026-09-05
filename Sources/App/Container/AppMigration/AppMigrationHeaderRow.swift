import SFSafeSymbols
import Shared
import SwiftUI

/// The illustration, title and description that open every migration screen, as a list row.
///
/// Not `AppleLikeListTopRowHeader`: that shrinks the title to `.title3` and boxes the artwork, which
/// suits a settings screen but not the first thing a user sees when asked to hand over their
/// credentials. This keeps the large title and the full-size illustration, and the caller strips the
/// row's insets and background so it reads as page furniture rather than as the first cell.
struct AppMigrationHeaderRow: View {
    let symbol: SFSymbol
    let title: String
    let primaryDescription: String
    var secondaryDescription: String?

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            AppMigrationIllustration(symbol: symbol)
                .padding(.top, DesignSystem.Spaces.two)

            Text(title)
                .font(DesignSystem.Font.largeTitle.bold())
                .multilineTextAlignment(.center)

            VStack(spacing: DesignSystem.Spaces.two) {
                Text(primaryDescription)
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let secondaryDescription {
                    Text(secondaryDescription)
                        .font(DesignSystem.Font.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignSystem.Spaces.two)
        .padding(.bottom, DesignSystem.Spaces.two)
    }
}

#Preview {
    List {
        AppMigrationHeaderRow(
            symbol: .arrowUpForwardApp,
            title: "Move to the new app",
            primaryDescription: "Home Assistant is moving to a new app.",
            secondaryDescription: "Your data goes straight from this app to the new one."
        )
        .appMigrationHeaderRowStyle()

        Section("A section") {
            Text("A row")
        }
    }
}
