import SFSafeSymbols
import Shared
import SwiftUI

/// One line of the intro screen's "moves automatically" / "needs setting up again" groups.
///
/// The symbol is centred against the text rather than pinned to its first line, so a one-line row and
/// a row that wraps to three still read as the same kind of thing.
struct AppMigrationDisclosureRow: View {
    let symbol: SFSymbol
    let tint: Color
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spaces.one) {
            Image(systemSymbol: symbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundStyle(tint)

            Text(text)
                .font(DesignSystem.Font.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, DesignSystem.Spaces.half)
        .frame(minHeight: AppMigrationRowMetrics.minimumHeight)
    }
}

#Preview {
    AppMigrationRowGroup(items: [
        "Short row",
        "A row long enough that it wraps onto more than one line, to check the symbol stays centred",
    ]) { line in
        AppMigrationDisclosureRow(symbol: .checkmarkCircleFill, tint: .haPrimary, text: line)
    }
    .padding()
}
