import Foundation
import Shared
import SwiftUI

struct WidgetBasicViewModel: Identifiable, Hashable {
    init(
        id: String,
        title: String,
        widgetURL: URL,
        icon: MaterialDesignIcons,
        textColor: Color = Color.black,
        iconColor: Color = Color.black,
        backgroundColor: Color = Color.white
    ) {
        self.id = id
        self.title = title
        self.widgetURL = widgetURL
        self.textColor = textColor
        self.icon = icon
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
    }

    var id: String

    var title: String
    var widgetURL: URL

    var icon: MaterialDesignIcons

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
                .fixedSize(horizontal: false, vertical: true)

            let icon = Text(verbatim: model.icon.unicode)
                .font(sizeStyle.iconFont)
                .minimumScaleFactor(0.2)
                .foregroundColor(model.iconColor)
                .fixedSize(horizontal: false, vertical: false)

            switch sizeStyle {
            case .regular, .condensed:
                HStack(alignment: .center, spacing: 6.0) {
                    icon
                    text
                    Spacer()
                }.padding(
                    .leading, 12
                )
            case .single, .expanded:
                VStack(alignment: .leading, spacing: 0) {
                    icon
                    Spacer()
                    text
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
