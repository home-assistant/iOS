import SwiftUI

extension View {
    /// Strips a list row back to bare content: no insets, no cell background, no separator.
    ///
    /// Applied to `AppMigrationHeaderRow` so the illustration and title sit on the list's own
    /// background and span its full width, instead of being inset and boxed like a real cell.
    func appMigrationHeaderRowStyle() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
