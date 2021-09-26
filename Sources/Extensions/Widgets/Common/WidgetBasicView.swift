import Foundation
import Shared
import SwiftUI

extension WidgetBasicSizeStyle {
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
    let model: WidgetBasicModel
    let sizeStyle: WidgetBasicSizeStyle

    init(model: WidgetBasicModel, sizeStyle: WidgetBasicSizeStyle) {
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
