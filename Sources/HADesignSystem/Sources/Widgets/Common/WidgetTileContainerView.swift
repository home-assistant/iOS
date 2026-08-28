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
    private let serverName: String?
    private let logo: Image?
    private let emptyView: () -> AnyView
    /// The reload control, when the widget offers one. `nil` leaves the footer off entirely.
    private let refreshControl: (() -> AnyView)?
    private let tileContent: WidgetTileGridView<Item>.TileContent
    private let tileRegions: WidgetTileGridView<Item>.TileRegions

    public init(
        contents: [Item],
        family: WidgetFamily,
        kind: WidgetTileKind,
        serverName: String? = nil,
        logo: Image? = nil,
        emptyView: @escaping () -> AnyView = { AnyView(EmptyView()) },
        refreshControl: (() -> AnyView)? = nil,
        tileContent: @escaping WidgetTileGridView<Item>.TileContent = { _, _, tile in tile },
        tileRegions: @escaping WidgetTileGridView<Item>.TileRegions = { _ in nil }
    ) {
        self.contents = contents
        self.family = family
        self.kind = kind
        self.serverName = serverName
        self.logo = logo
        self.emptyView = emptyView
        self.refreshControl = refreshControl
        self.tileContent = tileContent
        self.tileRegions = tileRegions
    }

    public var body: some View {
        VStack {
            if contents.isEmpty {
                emptyView()
            } else {
                grid
            }
            if let refreshControl, !contents.isEmpty {
                footer(refreshControl)
            }
        }
        // Whenever Apple allow apps to use material backgrounds we should update this
        .widgetBackground(.widgetPrimaryBackground)
    }

    private var grid: some View {
        let visible = Array(contents.prefix(WidgetTileLayout.size(for: family)))
        let rows = WidgetTileLayout.rows(for: family, models: visible)
        return WidgetTileGridView(
            rows: rows,
            sizeStyle: WidgetTileLayout.sizeStyle(
                family: family,
                modelsCount: visible.count,
                rowsCount: rows.count
            ),
            family: family,
            kind: kind,
            logo: logo,
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
