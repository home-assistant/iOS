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
    public let logo: Image?
    /// Splits the tile into an icon control and a body control. `nil` leaves it whole, for the tiles
    /// whose icon and body would run the same thing anyway.
    public let regions: WidgetTileRegions?

    public init(
        model: WidgetTileModel,
        sizeStyle: WidgetTileSizeStyle,
        family: WidgetFamily,
        tinted: Bool,
        logo: Image? = nil,
        regions: WidgetTileRegions? = nil
    ) {
        self.model = model
        self.sizeStyle = sizeStyle
        self.family = family
        self.tinted = tinted
        self.logo = logo
        self.regions = regions
    }

    public var body: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular:
            WidgetCircularIconView(icon: model.icon, logo: logo)
        case .accessoryInline:
            Label {
                Text(verbatim: model.title)
            } icon: {
                Image(uiImage: model.icon.image(ofSize: .init(width: 10, height: 10), color: .white))
            }
        default:
            tileView
        }
    }

    private var text: some View {
        Text(verbatim: model.title)
            .font(sizeStyle.textFont)
            .fontWeight(.semibold)
            .multilineTextAlignment(.leading)
            .foregroundStyle(model.useCustomColors ? model.textColor : Color(uiColor: .label))
            .lineLimit(2)
    }

    @ViewBuilder
    private var subtext: some View {
        if let subtitle = model.subtitle {
            Text(verbatim: subtitle)
                .font(sizeStyle.subtextFont)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var icon: some View {
        VStack {
            Text(verbatim: model.icon.unicode)
                .font(sizeStyle.iconFont(withBackground: model.showIconBackground))
                .foregroundColor(model.iconColor)
                .fixedSize(horizontal: false, vertical: false)
                // The glyph is a private-use character in the icon font, so VoiceOver has nothing
                // to say about it. The tile is named by its title instead.
                .accessibilityHidden(true)
        }
        // The slot stays the same size either way, so tiles line up whether or not their icon has
        // a background. Only the circle behind a background icon needs clipping — a bare glyph is
        // drawn larger and would be cut off by it.
        .frame(width: sizeStyle.iconCircleSize.width, height: sizeStyle.iconCircleSize.height)
        .modify { view in
            if model.showIconBackground {
                view
                    .background(model.iconColor.opacity(0.3))
                    .clipShape(Circle())
            } else {
                view
            }
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
            // Both halves are the same layout drawn twice — the card with its icon hidden, and the
            // icon alone laid over it — so splitting the tile in two cannot move anything by a
            // pixel. A hidden view takes no taps, which leaves each control exactly its own half.
            regions.body(AnyView(card(iconHidden: true)))
                .overlay {
                    layout(icon: AnyView(regions.icon(AnyView(iconAsControl))), contentHidden: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
        } else {
            card(iconHidden: false)
        }
    }

    private func card(iconHidden: Bool) -> some View {
        layout(
            icon: iconHidden ? AnyView(icon.hidden()) : AnyView(icon),
            contentHidden: false
        )
        .widgetTileCardStyle(sizeStyle: sizeStyle, model: model, tinted: tinted)
    }

    /// The tile's arrangement, with either half able to drop out so the other can be drawn on its
    /// own without the two copies ever disagreeing about where anything sits.
    private func layout(icon iconView: AnyView, contentHidden: Bool) -> some View {
        VStack(alignment: .leading) {
            Group {
                switch sizeStyle {
                case .regular, .compact, .compressed:
                    HStack(alignment: .center, spacing: DesignSystem.Spaces.oneAndHalf) {
                        iconView
                        content(hidden: contentHidden) {
                            VStack(alignment: .leading, spacing: .zero) {
                                text
                                subtext
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding([.leading, .trailing], DesignSystem.Spaces.oneAndHalf)
                case .single, .expanded:
                    VStack(alignment: .leading, spacing: 0) {
                        iconView
                        Spacer()
                        content(hidden: contentHidden) {
                            VStack(alignment: .leading, spacing: 0) {
                                text
                                subtext
                            }
                        }
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

    @ViewBuilder
    private func content(hidden: Bool, @ViewBuilder _ view: () -> some View) -> some View {
        if hidden {
            view().hidden()
        } else {
            view()
        }
    }
}

#Preview {
    WidgetTileButtonView(
        model: .init(id: "1", title: "Kitchen light", subtitle: "On", icon: .lightbulbIcon),
        sizeStyle: .single,
        family: .systemSmall,
        tinted: false
    )
    .frame(width: 160, height: 160)
}
#endif
