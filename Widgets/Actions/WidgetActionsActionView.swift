import Shared
import SwiftUI
import WidgetKit

struct WidgetActionsActionView: View {
    let action: Action
    @SwiftUI.Environment(\.widgetFamily) var family: WidgetFamily

    init(action: Action) {
        self.action = action
        MaterialDesignIcons.register()
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Color(hex: action.BackgroundColor)
            VStack(alignment: .leading) {
                Text(verbatim: MaterialDesignIcons(named: action.IconName).unicode)
                    .font(.custom(MaterialDesignIcons.familyName, size: 38.0))
                    .minimumScaleFactor(0.2)
                    .foregroundColor(.init(hex: action.IconColor))
                Spacer()
                Text(verbatim: action.Text)
                    .font(family == .systemSmall ? .subheadline : .footnote)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.init(hex: action.TextColor))
            }
            .padding()
        }
    }
}

#if DEBUG
struct WidgetActionsActionView_Previews: PreviewProvider {
    static func shortAction() -> some View {
        WidgetActionsActionView(action: with(Action()) {
            $0.Text = "Short Name"
        })
    }

    static func longAction() -> some View {
        WidgetActionsActionView(action: with(Action()) {
            $0.Text = "Very Long Name Which Exceeds One Line"
        })
    }

    static var previews: some View {
        shortAction()
        .previewContext(WidgetPreviewContext(family: .systemSmall))

        longAction()
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
#endif
