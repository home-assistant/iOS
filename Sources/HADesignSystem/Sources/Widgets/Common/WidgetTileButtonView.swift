#if !os(watchOS)
import Foundation
import HAIconic
import SwiftUI
import WidgetKit

/// A tile the user taps: the icon leads, with the title and subtitle beside or below it depending on
/// how much room ``WidgetTileSizeStyle`` says there is.
///
/// The accessory families have no room for a tile at all, so they fall back to the circular glyph or
/// a single inline line.
public struct WidgetTileButtonView: View {
    public let model: WidgetTileModel
    public let sizeStyle: WidgetTileSizeStyle
    public let family: WidgetFamily
    public let tinted: Bool
    /// Splits the tile into an icon control and a body control. `nil` leaves it whole, for the tiles
    /// whose icon and body would run the same thing anyway.
    public let regions: WidgetTileRegions?
    /// How tall the row this tile is drawn in turns out to be, which is what its icon is sized from.
    @Environment(\.widgetTileRowHeight) private var rowHeight

    public init(
        model: WidgetTileModel,
        sizeStyle: WidgetTileSizeStyle,
        family: WidgetFamily,
        tinted: Bool,
        regions: WidgetTileRegions? = nil
    ) {
        self.model = model
        self.sizeStyle = sizeStyle
        self.family = family
        self.tinted = tinted
        self.regions = regions
    }

    /// The inline family draws its icon at the size the system leaves for one, next to the title.
    private static let inlineIconSize: CGFloat = 12

    public var body: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular:
            WidgetCircularIconView(icon: model.icon)
        case .accessoryInline:
            Label {
                Text(verbatim: model.title)
            } icon: {
                WidgetAccessoryIconView(icon: model.icon, size: Self.inlineIconSize)
            }
        default:
            tileView
        }
    }

    /// How far the area and the state may shrink before they start truncating.
    ///
    /// Only those two: they are the lines that carry a room or an entity state that is often longer
    /// than the tile is wide, and they are already the smaller type, so a little scaling reads as
    /// the line fitting rather than as a third text size on the tile. The name keeps its size.
    private static let secondaryMinimumScale: CGFloat = 0.8

    /// Whether this tile draws its area: only when it has one, and only at a size with room for a
    /// third line of text.
    private var showsArea: Bool {
        model.area != nil && sizeStyle.showsAreaLine
    }

    private var text: some View {
        Text(verbatim: model.title)
            .font(sizeStyle.textFont)
            .fontWeight(.semibold)
            .multilineTextAlignment(.leading)
            .foregroundStyle(model.useCustomColors ? model.textColor : Color(uiColor: .label))
            // Three lines is the tile's budget, and the name takes whatever the area and the
            // state leave of it — so a tile whose widget hides states still wraps to two lines.
            .lineLimit(showsArea && model.subtitle != nil ? 1 : 2)
    }

    @ViewBuilder
    private var subtext: some View {
        if let subtitle = model.subtitle {
            Text(verbatim: subtitle)
                .font(sizeStyle.subtextFont)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .lineLimit(1)
                .minimumScaleFactor(Self.secondaryMinimumScale)
                .truncationMode(.tail)
                .modify { view in
                    if #available(iOS 17, *) {
                        view.invalidatableContent()
                    } else {
                        view
                    }
                }
        }
    }

    @ViewBuilder
    private var areaText: some View {
        if showsArea, let area = model.area {
            Text(verbatim: area)
                .font(sizeStyle.subtextFont)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .lineLimit(1)
                .minimumScaleFactor(Self.secondaryMinimumScale)
                .truncationMode(.tail)
        }
    }

    /// Area, name, state — stacked the way the Home app stacks them, so each one truncates on its
    /// own line instead of being squeezed off the end of a line it shares.
    private var textStack: some View {
        VStack(alignment: .leading, spacing: .zero) {
            areaText
            text
            subtext
        }
    }

    private var icon: some View {
        WidgetTileIconView(model: model, sizeStyle: sizeStyle, rowHeight: iconRowHeight)
    }

    /// The height the icon is sized from: the row's, but only where the icon sits beside the text.
    /// The sizes that stack it above the text have the whole tile to fill and are drawn as they are.
    private var iconRowHeight: CGFloat? {
        switch sizeStyle {
        case .regular, .compact, .dense, .compressed: rowHeight
        case .single, .expanded: nil
        }
    }

    /// The icon as its own control. Splitting the tile makes the icon reachable on its own, so it
    /// has to carry the tile's name — the title it used to be announced with lives in the other
    /// half now.
    private var iconAsControl: some View {
        icon
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: model.title))
    }

    @ViewBuilder
    private var tileView: some View {
        if let regions {
            // The two controls sit side by side, never one over the other. WidgetKit does not hit
            // test a widget the way SwiftUI does: it archives the frames of its links and intent
            // controls and picks a tap's owner from those, and a `Link` spanning the whole card took
            // every tap meant for the control drawn over its icon — so the icon opened the app. Each
            // half now owns exactly its own frame, the way the todo list lays its checkbox beside
            // its row link.
            layout(
                icon: AnyView(regions.icon(AnyView(iconAsControl))),
                body: { body in AnyView(regions.body(body)) }
            )
            .widgetTileCardStyle(sizeStyle: sizeStyle, model: model, tinted: tinted)
        } else {
            layout(icon: AnyView(icon), body: { body in body })
                .widgetTileCardStyle(sizeStyle: sizeStyle, model: model, tinted: tinted)
        }
    }

    /// The tile's arrangement. `body` wraps every part of the tile that is not the icon in the
    /// control that opens it, and is the identity for a tile that is one control. Whatever it wraps
    /// is stretched to fill the room beside or below the icon, so the body's tap area is the whole
    /// card minus the icon, not just the text.
    private func layout(icon iconView: AnyView, body: (AnyView) -> AnyView) -> some View {
        VStack(alignment: .leading) {
            Group {
                switch sizeStyle {
                case .regular, .compact, .dense, .compressed:
                    HStack(alignment: .center, spacing: sizeStyle.horizontalPadding) {
                        iconView
                        body(AnyView(
                            textStack
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        ))
                    }
                    .padding([.leading, .trailing], sizeStyle.horizontalPadding)
                case .single, .expanded:
                    VStack(alignment: .leading, spacing: 0) {
                        // The row beside the icon is empty, but it is still part of the tile, so a
                        // second body control covers it; pinned to the icon's height so it never
                        // pushes the text down.
                        HStack(alignment: .top, spacing: 0) {
                            iconView
                            body(AnyView(
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .contentShape(Rectangle())
                            ))
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        body(AnyView(
                            VStack(alignment: .leading, spacing: 0) {
                                Spacer()
                                textStack
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        ))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, sizeStyle == .regular ? 10 : /* use default */ nil)
                }
            }
            .modify { view in
                if #available(iOS 18, *) {
                    view.widgetAccentable()
                } else {
                    view
                }
            }
        }
    }
}

#Preview {
    WidgetTileButtonView(
        model: .init(id: "1", title: "Kitchen light", subtitle: "On", area: "Kitchen", icon: .lightbulbIcon),
        sizeStyle: .single,
        family: .systemSmall,
        tinted: false
    )
    .frame(width: 160, height: 160)
}
#endif
