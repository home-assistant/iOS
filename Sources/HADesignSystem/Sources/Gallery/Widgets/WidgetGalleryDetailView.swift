#if !os(watchOS)
import SwiftUI

/// One widget at every family it supports, so a change to a component can be read against all the
/// sizes it has to survive at once.
public struct WidgetGalleryDetailView: View {
    private let item: WidgetGalleryItem

    public init(item: WidgetGalleryItem) {
        self.item = item
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.three) {
                Text(verbatim: item.subtitle)
                    .font(DesignSystem.Font.footnote)
                    .foregroundStyle(.secondary)
                ForEach(Array(item.families.enumerated()), id: \.offset) { _, family in
                    WidgetGalleryPreview(family: family) {
                        item.preview(for: family)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spaces.two)
        }
        .navigationTitle(item.title)
    }
}

#Preview {
    NavigationStack {
        WidgetGalleryDetailView(item: .actions)
    }
}
#endif
