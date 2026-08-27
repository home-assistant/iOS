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

    public init(
        model: WidgetTileModel,
        sizeStyle: WidgetTileSizeStyle,
        family: WidgetFamily,
        tinted: Bool,
        logo: Image? = nil
    ) {
        self.model = model
        self.sizeStyle = sizeStyle
        self.family = family
        self.tinted = tinted
        self.logo = logo
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
                .font(sizeStyle.iconFont)
                .foregroundColor(model.iconColor)
                .fixedSize(horizontal: false, vertical: false)
        }
        .frame(width: sizeStyle.iconCircleSize.width, height: sizeStyle.iconCircleSize.height)
        .background(model.showIconBackground ? model.iconColor.opacity(0.3) : Color.clear)
        .clipShape(Circle())
    }

    private var tileView: some View {
        VStack(alignment: .leading) {
            Group {
                switch sizeStyle {
                case .regular, .compact, .compressed:
                    HStack(alignment: .center, spacing: DesignSystem.Spaces.oneAndHalf) {
                        icon
                        VStack(alignment: .leading, spacing: .zero) {
                            text
                            subtext
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding([.leading, .trailing], DesignSystem.Spaces.oneAndHalf)
                case .single, .expanded:
                    VStack(alignment: .leading, spacing: 0) {
                        icon
                        Spacer()
                        text
                        subtext
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
        .widgetTileCardStyle(sizeStyle: sizeStyle, model: model, tinted: tinted)
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
