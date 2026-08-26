#if !os(watchOS)
import SwiftUI

/// Every widget the app ships, drawn from the design system's own components with mocked data, at
/// the size each widget family really gets.
public struct WidgetsGalleryView: View {
    public init() {}

    public var body: some View {
        List {
            ForEach(WidgetGalleryItem.allCases) { item in
                NavigationLink {
                    WidgetGalleryDetailView(item: item)
                } label: {
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                        Text(verbatim: item.title)
                        Text(verbatim: item.subtitle)
                            .font(DesignSystem.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Widgets")
    }
}

#Preview {
    NavigationStack {
        WidgetsGalleryView()
    }
}
#endif
