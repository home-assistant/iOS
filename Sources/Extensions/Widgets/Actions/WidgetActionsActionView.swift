import Shared
import SwiftUI
import WidgetKit

struct WidgetActionsActionView: View {
    let action: Action
    let sizeStyle: SizeStyle
    @SwiftUI.Environment(\.widgetFamily) var family: WidgetFamily

    enum SizeStyle {
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

    init(action: Action, sizeStyle: SizeStyle) {
        self.action = action
        self.sizeStyle = sizeStyle
        MaterialDesignIcons.register()
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Color(hex: action.BackgroundColor)

            let text = Text(verbatim: action.Text)
                .font(sizeStyle.font)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
                .foregroundColor(.init(hex: action.TextColor))

            if case .multiple(_, condensed: true) = sizeStyle {
                HStack(alignment: .center) {
                    Text(verbatim: MaterialDesignIcons(named: action.IconName).unicode)
                        .font(.custom(MaterialDesignIcons.familyName, size: 16.0))
                        .foregroundColor(.init(hex: action.IconColor))
                    text
                        .lineLimit(1)
                    Spacer()
                }
                .padding([.leading, .trailing])
            } else {
                VStack(alignment: .leading) {
                    Text(verbatim: MaterialDesignIcons(named: action.IconName).unicode)
                        .font(.custom(MaterialDesignIcons.familyName, size: 38.0))
                        .minimumScaleFactor(0.2)
                        .foregroundColor(.init(hex: action.IconColor))
                    Spacer()
                    text
                }
                .padding()
            }
        }
    }
}

#if DEBUG
struct WidgetActionsActionView_Previews: PreviewProvider {
    static func shortAction() -> some View {
        WidgetActionsActionView(action: with(Action()) {
            $0.Text = "Short Name"
        }, sizeStyle: .single)
    }

    static func longAction() -> some View {
        WidgetActionsActionView(action: with(Action()) {
            $0.Text = "Very Long Name Which Exceeds One Line"
        }, sizeStyle: .single)
    }

    static var previews: some View {
        shortAction()
            .previewContext(WidgetPreviewContext(family: .systemSmall))

        longAction()
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
#endif
