import Shared
import SwiftUI
import WidgetKit

/// A grid of widget tiles, drawn by the design system and made interactive by
/// ``WidgetTileInteraction``.
struct WidgetBasicView: View {
    let type: WidgetType
    let rows: [[WidgetBasicViewModel]]
    let sizeStyle: WidgetTileSizeStyle
    let family: WidgetFamily

    var body: some View {
        let interaction = WidgetTileInteraction(type: type, family: family)
        WidgetTileGridView(
            rows: rows,
            sizeStyle: sizeStyle,
            family: family,
            kind: type.tileKind,
            tileContent: interaction.content,
            tileRegions: interaction.regions
        )
    }
}

#Preview {
    WidgetBasicView(
        type: .button,
        rows: [[
            .init(
                id: "1",
                title: "Title",
                subtitle: "Subtitle",
                interactionType: .appIntent(.refresh),
                icon: .abTestingIcon,
                disabled: true
            ),
            .init(
                id: "2",
                title: "Title",
                subtitle: "Subtitle",
                interactionType: .appIntent(.refresh),
                icon: .abTestingIcon,
                disabled: true
            ),
            .init(
                id: "3",
                title: "Title",
                subtitle: "Subtitle",
                interactionType: .appIntent(.refresh),
                icon: .abTestingIcon,
                disabled: true
            ),
        ]],
        sizeStyle: .compressed,
        family: .systemMedium
    )
}
