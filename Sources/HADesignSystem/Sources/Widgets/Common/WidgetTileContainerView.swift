#if !os(watchOS)
import Foundation
import HAIconic
import SwiftUI
import WidgetKit

/// A whole tile-based widget: the grid filled to whatever the family holds, the empty state when
/// there is nothing to fill it with, and the optional footer carrying the server and the reload
/// control.
public struct WidgetTileContainerView<Item: WidgetTileRepresentable>: View {
    private let contents: [Item]
    private let family: WidgetFamily
    private let kind: WidgetTileKind
    private let capacity: WidgetTileCapacity
    private let serverName: String?
    private let emptyView: () -> AnyView
    /// The reload control, when the widget offers one. `nil` leaves the footer off entirely.
    private let refreshControl: (() -> AnyView)?
    private let tileContent: WidgetTileGridView<Item>.TileContent
    private let tileRegions: WidgetTileGridView<Item>.TileRegions

    public init(
        contents: [Item],
        family: WidgetFamily,
        kind: WidgetTileKind,
        capacity: WidgetTileCapacity = .packed,
        serverName: String? = nil,
        emptyView: @escaping () -> AnyView = { AnyView(EmptyView()) },
        refreshControl: (() -> AnyView)? = nil,
        tileContent: @escaping WidgetTileGridView<Item>.TileContent = { _, _, tile in tile },
        tileRegions: @escaping WidgetTileGridView<Item>.TileRegions = { _ in nil }
    ) {
        self.contents = contents
        self.family = family
        self.kind = kind
        self.capacity = capacity
        self.serverName = serverName
        self.emptyView = emptyView
        self.refreshControl = refreshControl
        self.tileContent = tileContent
        self.tileRegions = tileRegions
    }

    public var body: some View {
        VStack {
            if contents.isEmpty {
                empty
            } else if family == .accessoryCircular {
                circularAccessory
            } else {
                grid
            }
            // A lock screen accessory has no room for a footer, and nothing to reload from there.
            if let refreshControl, !contents.isEmpty, !family.isLockScreenAccessory {
                footer(refreshControl)
            }
        }
        // The lock screen draws its accessories over the wallpaper, so a background of ours there
        // would paint over the slot the system means to keep translucent — the circular accessory
        // brings its own `AccessoryWidgetBackground`.
        // Whenever Apple allow apps to use material backgrounds we should update this
        .widgetBackground(
            family.isLockScreenAccessory ? AnyShapeStyle(Color.clear) : AnyShapeStyle(Color.widgetPrimaryBackground)
        )
    }

    /// Nothing to show. The lock screen has no room for the widget's own wording, so it falls back
    /// to the brand glyph — a circular accessory drawn with a line of clipped text reads as broken,
    /// where the mark reads as "this is the Home Assistant widget, and it is empty".
    @ViewBuilder
    private var empty: some View {
        if family == .accessoryCircular {
            WidgetCircularIconView(icon: .homeAssistantIcon)
        } else {
            emptyView()
        }
    }

    /// The circular accessory holds one item, and that item is the whole widget: its glyph, wrapped
    /// in the control that runs it, filling the slot.
    ///
    /// Not the grid. The grid wraps a tile in its control from the outside, which for this family
    /// would put the accessory's system background and the reader it is measured from inside the
    /// control's label — and a lock screen button only runs its intent when the tap lands on its
    /// label. See ``WidgetCircularAccessoryView`` for what that did to the scripts widget.
    private var circularAccessory: some View {
        // `WidgetTileLayout.size` gives this family exactly one, and `contents` is not empty here.
        let item = contents[0]
        return WidgetCircularAccessoryView(icon: item.tileModel.icon) { glyph in
            tileContent(item, .single, glyph)
        }
    }

    private var grid: some View {
        let visible = Array(contents.prefix(WidgetTileLayout.size(for: family, capacity: capacity)))
        let rows = WidgetTileLayout.rows(for: family, models: visible, capacity: capacity)
        return WidgetTileGridView(
            rows: rows,
            sizeStyle: WidgetTileLayout.sizeStyle(
                family: family,
                modelsCount: visible.count,
                rowsCount: rows.count
            ),
            family: family,
            kind: kind,
            // The footer, when there is one, is what sits against the widget's bottom edge.
            reachesBottomEdge: refreshControl == nil,
            tileContent: tileContent,
            tileRegions: tileRegions
        )
    }

    /// The last refresh time doubles as the reload control, matching the energy widget: tapping the
    /// glyph or the time reloads this widget's timeline.
    private func footer(_ refreshControl: () -> AnyView) -> some View {
        HStack(spacing: DesignSystem.Spaces.half) {
            if let serverName {
                Text(verbatim: "\(serverName) ·")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            refreshControl()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, DesignSystem.Spaces.half)
        .padding(.bottom, DesignSystem.Spaces.half)
    }
}

#Preview {
    WidgetTileContainerView(
        contents: (0 ..< 6).map { index in
            WidgetTileModel(id: "\(index)", title: "Title \(index)", subtitle: "Subtitle", icon: .abTestingIcon)
        },
        family: .systemMedium,
        kind: .button,
        serverName: "Home",
        refreshControl: { AnyView(WidgetRefreshLabel(date: Date(timeIntervalSince1970: 1_700_000_000))) }
    )
    .frame(width: 338, height: 158)
}
#endif
