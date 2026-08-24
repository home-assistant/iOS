import Shared
import SwiftUI

/// A grouped container for the migration screens' rows, with a separator between each one.
///
/// These screens are built on `BaseOnboardingView`, which is a scroll view rather than a `List`, so
/// there are no sections to fall back on. This gives the rows the same grouped, rounded backing and
/// separators a list section would, without dragging a whole `List` into a layout that is centred
/// prose.
///
/// Takes the items and builds the rows itself rather than accepting arbitrary content, because the
/// separators have to go *between* rows — which means the container has to know where the boundaries
/// are instead of receiving one opaque blob of view.
struct AppMigrationRowGroup<Item: Hashable, RowContent: View>: View {
    let items: [Item]
    /// Where each separator starts, so it aligns with the row's text and not its symbol.
    var separatorInset: CGFloat = AppMigrationRowMetrics.disclosureSeparatorInset
    @ViewBuilder let row: (Item) -> RowContent

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                row(item)

                if index < items.count - 1 {
                    Divider()
                        .padding(.leading, separatorInset)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spaces.two)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(
            RoundedRectangle(cornerRadius: AppMigrationRowMetrics.cornerRadius, style: .continuous)
        )
    }
}

#Preview {
    AppMigrationRowGroup(items: [
        "3 Home Assistant connections, still signed in",
        "Your widgets, watch, CarPlay and notification configuration",
        "Your app settings and privacy choices",
    ]) { line in
        AppMigrationDisclosureRow(symbol: .checkmarkCircleFill, tint: .haPrimary, text: line)
    }
    .padding()
}
