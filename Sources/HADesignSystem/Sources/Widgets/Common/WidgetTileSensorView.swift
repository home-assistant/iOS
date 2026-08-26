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
                Text(model.title)
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
                .font(sizeStyle.iconFont)
                .foregroundColor(model.iconColor)
                .fixedSize(horizontal: false, vertical: false)
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
