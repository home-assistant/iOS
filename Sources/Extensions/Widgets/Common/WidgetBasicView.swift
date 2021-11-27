import Foundation
import Shared
import SwiftUI

struct WidgetBasicViewModel: Identifiable, Hashable {
    init(
        id: String,
        title: String,
        subtitle: String?,
        widgetURL: URL,
        icon: MaterialDesignIcons,
        showsChevron: Bool = false,
        textColor: Color = Color.black,
        iconColor: Color = Color.black,
        backgroundColor: Color = Color.white
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.widgetURL = widgetURL
        self.textColor = textColor
        self.icon = icon
        self.showsChevron = showsChevron
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
    }

    var id: String

    var title: String
    var subtitle: String?
    var widgetURL: URL

    var icon: MaterialDesignIcons
    var showsChevron: Bool

    var backgroundColor: Color
    var textColor: Color
    var iconColor: Color
}

enum WidgetBasicSizeStyle {
    case single
    case expanded
    case condensed
    case regular

    var textFont: Font {
        switch self {
        case .single, .expanded:
            return .subheadline
        case .condensed, .regular:
            return .footnote
        }
    }

    var subtextFont: Font {
        switch self {
        case .single, .expanded:
            return .footnote
        case .regular, .condensed:
            return .system(size: 12)
        }
    }

    var iconFont: Font {
        let size: CGFloat

        switch self {
        case .single, .expanded:
            size = 38
        case .regular:
            size = 28
        case .condensed:
            size = 18
        }

        return .custom(MaterialDesignIcons.familyName, size: size)
    }

    var chevronFont: Font {
        let size: CGFloat

        switch self {
        case .single, .expanded:
            size = 18
        case .regular:
            size = 14
        case .condensed:
            size = 9
        }

        return .system(size: size, weight: .bold)
    }
}

struct WidgetBasicView: View {
    let model: WidgetBasicViewModel
    let sizeStyle: WidgetBasicSizeStyle

    init(model: WidgetBasicViewModel, sizeStyle: WidgetBasicSizeStyle) {
        self.model = model
        self.sizeStyle = sizeStyle
        MaterialDesignIcons.register()
    }

    var body: some View {
        ZStack(alignment: .leading) {
            model.backgroundColor

            Rectangle().fill(
                LinearGradient(
                    gradient: .init(colors: [.white.opacity(0.06), .black.opacity(0.06)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            let text = Text(verbatim: model.title)
                .font(sizeStyle.textFont)
                .fontWeight(.semibold)
                .multilineTextAlignment(.leading)
                .foregroundColor(model.textColor)
                .lineLimit(nil)
                .minimumScaleFactor(0.5)

            let subtext: AnyView? = {
                guard let subtitle = model.subtitle else {
                    return nil
                }

                return AnyView(
                    Text(verbatim: subtitle)
                        .font(sizeStyle.subtextFont)
                        .foregroundColor(model.textColor.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.middle)
                )
            }()

            let icon = HStack(alignment: .top, spacing: -1) {
                Text(verbatim: model.icon.unicode)
                    .font(sizeStyle.iconFont)
                    .minimumScaleFactor(0.2)
                    .foregroundColor(model.iconColor)
                    .fixedSize(horizontal: false, vertical: false)

                if model.showsChevron {
                    // this sfsymbols is a little more legible at smaller size than mdi:open-in-new
                    Image(systemName: "arrow.up.forward.app")
                        .font(sizeStyle.chevronFont)
                        .foregroundColor(model.iconColor)
                }
            }

            switch sizeStyle {
            case .regular, .condensed:
                HStack(alignment: .center, spacing: 6.0) {
                    icon
                    if let subtext = subtext {
                        VStack(alignment: .leading, spacing: -2) {
                            text
                            subtext
                        }
                    } else {
                        text
                    }
                    Spacer()
                }.padding(
                    .leading, 12
                )
            case .single, .expanded:
                VStack(alignment: .leading, spacing: 0) {
                    icon
                    Spacer()
                    text
                    if let subtext = subtext {
                        subtext
                    }
                }.padding(
                    [.leading, .trailing]
                ).padding(
                    [.top, .bottom],
                    sizeStyle == .regular ? 10 : /* use default */ nil
                )
            }
        }
    }
}
