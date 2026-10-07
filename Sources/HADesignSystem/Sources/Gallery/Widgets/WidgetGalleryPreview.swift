#if !os(watchOS)
import SwiftUI
import WidgetKit

/// One widget drawn at the size its family really gets, captioned with the family's name.
///
/// Home screen families sit on the widget background the system gives them; lock screen ones sit on
/// a dark backdrop, which is the closest a plain SwiftUI view gets to how they are actually
/// rendered.
public struct WidgetGalleryPreview<Content: View>: View {
    private let family: WidgetFamily
    private let content: Content

    public init(family: WidgetFamily, @ViewBuilder content: () -> Content) {
        self.family = family
        self.content = content()
    }

    public var body: some View {
        let size = WidgetGalleryFamilyMetrics.size(for: family)
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            Text(verbatim: WidgetGalleryFamilyMetrics.title(for: family))
                .font(DesignSystem.Font.caption2)
                .foregroundStyle(.secondary)
            framed(size: size)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The lock screen renders its accessories light-on-dark whatever the phone's appearance is, so
    /// those previews pin the colour scheme; the home screen ones follow the reader's.
    @ViewBuilder
    private func framed(size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: WidgetGalleryFamilyMetrics.cornerRadius(for: family))
        if WidgetGalleryFamilyMetrics.isAccessory(family) {
            content
                .frame(width: size.width, height: size.height)
                .background(Color.black)
                .clipShape(shape)
                .environment(\.colorScheme, .dark)
        } else {
            content
                .frame(width: size.width, height: size.height)
                .background(Color.widgetPrimaryBackground)
                .clipShape(shape)
        }
    }
}

#Preview {
    let models = WidgetTileSampleData.actions(fitting: .systemMedium)
    return WidgetGalleryPreview(family: .systemMedium) {
        WidgetTileGridView(
            rows: WidgetTileLayout.rows(for: .systemMedium, models: models),
            sizeStyle: .compact,
            family: .systemMedium,
            kind: .button
        )
    }
    .padding()
}
#endif
