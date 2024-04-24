import SwiftUI
import WidgetKit

@main
struct Widgets: WidgetBundle {
    var body: some Widget {
        WidgetAssist()
        actionsWidget()
        WidgetOpenPage()
    }

    private func actionsWidget() -> some Widget {
        if #available(iOS 17, *) {
            return WidgetActions()
        } else {
            return LegacyWidgetActions()
        }
    }
}
