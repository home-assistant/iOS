import Foundation
import Shared
import SwiftUI

struct WidgetBasicViewModel: Identifiable, Hashable {
    init(
        id: String,
        title: String,
        widgetURL: URL,
        icon: String,
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

    var icon: String

    var backgroundColor: Color
    var textColor: Color
    var iconColor: Color
}

enum WidgetBasicSizeStyle {
    case single
    case multiple(expanded: Bool, condensed: Bool)

    var font: Font {
        switch self {
        case .single:
            return .subheadline
        case let .multiple(expanded: expanded, _):
            return expanded ? .subheadline : .footnote
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
            model.backgroundColor

            let text = Text(verbatim: model.title)
                .font(sizeStyle.font)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
                .foregroundColor(model.textColor)

            if case .multiple(_, condensed: true) = sizeStyle {
                HStack(alignment: .center) {
                    Text(verbatim: MaterialDesignIcons(named: model.icon).unicode)
                        .font(.custom(MaterialDesignIcons.familyName, size: 16.0))
                        .foregroundColor(model.iconColor)
                    text
                        .lineLimit(1)
                    Spacer()
                }
                .padding([.leading])
            } else {
                VStack(alignment: .leading) {
                    Text(verbatim: MaterialDesignIcons(named: model.icon).unicode)
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
