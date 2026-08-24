import SFSafeSymbols
import Shared
import SwiftUI

/// The leading symbol of every row in the migration flow.
///
/// One component, and sized by the text rather than by a hard-coded frame, so the disclosure rows on
/// the intro and the step rows on the progress screens have identical metrics — the two lists sit
/// one screen apart and any difference between them shows.
struct AppMigrationRowIcon: View {
    let symbol: SFSymbol
    var tint: Color = .haPrimary

    /// A fixed column so the text of every row starts at the same x, whatever the symbol's width.
    private static let columnWidth: CGFloat = 28

    var body: some View {
        Image(systemSymbol: symbol)
            .imageScale(.large)
            .foregroundStyle(tint)
            .frame(width: Self.columnWidth, alignment: .center)
    }
}

#Preview {
    List {
        Label { Text("Standard label for comparison") } icon: { Image(systemSymbol: .gearshape) }
        HStack { AppMigrationRowIcon(symbol: .gearshape); Text("Migration row") }
    }
}
