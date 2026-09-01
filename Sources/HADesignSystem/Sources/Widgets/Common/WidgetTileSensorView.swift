#if !os(watchOS)
import Foundation
import HAIconic
import SwiftUI
import WidgetKit

/// A tile that reports a reading: the value leads and the icon is pushed to the trailing edge, so a
/// column of sensors reads as a column of numbers rather than a column of glyphs.
public struct WidgetTileSensorView: View {
    public let model: WidgetTileModel
    public let sizeStyle: WidgetTileSizeStyle
    public let family: WidgetFamily
    public let tinted: Bool

    public init(
        model: WidgetTileModel,
        sizeStyle: WidgetTileSizeStyle,
        family: WidgetFamily,
        tinted: Bool
    ) {
        self.model = model
        self.sizeStyle = sizeStyle
        self.family = family
        self.tinted = tinted
    }

    /// The inline family draws its icon at the size the system leaves for one, next to the reading.
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

    private var text: some View {
        Text(verbatim: model.title)
            .font(sizeStyle.textFont)
            .fontWeight(.semibold)
            .multilineTextAlignment(.leading)
            .foregroundStyle(model.useCustomColors ? model.textColor : Color(uiColor: .label))
            .lineLimit(1)
    }

    @ViewBuilder
    private var subtext: some View {
        if let subtitle = model.subtitle {
            Text(verbatim: subtitle)
                .font(sizeStyle.subtextFont)
                .foregroundStyle(model.useCustomColors ? model.textColor : Color(uiColor: .label))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var icon: some View {
        VStack {
            Text(verbatim: model.icon.unicode)
                // A reading's icon never sits in a circle, so it follows the same rule as a bare
                // icon on an action tile and is drawn half as large again.
                .font(sizeStyle.iconFont(withBackground: false))
                .foregroundColor(model.iconColor)
                .fixedSize(horizontal: false, vertical: false)
                // The glyph is a private-use character in the icon font, so VoiceOver has nothing
                // to say about it. The tile is named by its title instead.
                .accessibilityHidden(true)
        }
    }

    private var tileView: some View {
        VStack(alignment: .leading) {
            Group {
                switch sizeStyle {
                case .regular, .compact, .compressed:
                    HStack(alignment: .center, spacing: DesignSystem.Spaces.oneAndHalf) {
                        VStack(alignment: .leading, spacing: .zero) {
                            subtext
                            text
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        icon
                            .offset(y: -10)
                    }
                    .padding([.leading, .trailing], DesignSystem.Spaces.oneAndHalf)
                case .single, .expanded:
                    VStack(alignment: .leading, spacing: 0) {
                        icon
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Spacer()
                        subtext
                        text
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
    WidgetTileSensorView(
        model: .init(id: "1", title: "21.4 °C", subtitle: "Living room", icon: .thermometerIcon),
        sizeStyle: .single,
        family: .systemSmall,
        tinted: false
    )
    .frame(width: 160, height: 160)
}
#endif
