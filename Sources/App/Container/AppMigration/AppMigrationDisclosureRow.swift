import SFSafeSymbols
import Shared
import SwiftUI

/// One line of the intro screen's "moves automatically" / "needs setting up again" sections.
///
/// No explicit height or padding: the row takes the standard list metrics, so it matches every other
/// list in the app rather than a size picked for this flow.
struct AppMigrationDisclosureRow: View {
    let symbol: SFSymbol
    let tint: Color
    let text: String

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            AppMigrationRowIcon(symbol: symbol, tint: tint)

            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    List {
        Section("A section") {
            AppMigrationDisclosureRow(symbol: .checkmarkCircleFill, tint: .green, text: "Short row")
            AppMigrationDisclosureRow(
                symbol: .arrowClockwise,
                tint: .secondary,
                text: "A row long enough that it wraps onto more than one line, to check it still lines up"
            )
        }
    }
}
