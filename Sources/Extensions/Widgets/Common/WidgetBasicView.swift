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

            switch sizeStyle {
            case .condensed:
                HStack(alignment: .center) {
                    Text(verbatim: model.icon.unicode)
                        .font(.custom(MaterialDesignIcons.familyName, size: 16.0))
                        .foregroundColor(model.iconColor)
                    text
                    Spacer()
                }
                .padding([.leading])
            case .regular, .expanded, .single:
                VStack(alignment: .leading) {
                    Text(verbatim: model.icon.unicode)
                        .font(.custom(MaterialDesignIcons.familyName, size: 38.0))
                        .minimumScaleFactor(0.2)
                        .foregroundColor(model.iconColor)
                    Spacer()
                    text
                }
                .padding()
            }
        }
    }
}
