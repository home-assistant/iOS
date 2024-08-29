import Shared
import SwiftUI
import WidgetKit

@main
enum WidgetLauncher {
    static func main() {
        if #available(iOSApplicationExtension 18.0, *) {
            WidgetsBundle18.main()
        } else if #available(iOSApplicationExtension 17.0, *) {
            WidgetsBundle17.main()
        } else {
            WidgetsBundleLegacy.main()
        }
    }
}

struct WidgetsBundleLegacy: WidgetBundle {
    init() {
        MaterialDesignIcons.register()
    }

    var body: some Widget {
        WidgetAssist()
        LegacyWidgetActions()
        WidgetOpenPage()
    }
}

@available(iOSApplicationExtension 17.0, *)
struct WidgetsBundle17: WidgetBundle {
    init() {
        MaterialDesignIcons.register()
    }

    var body: some Widget {
        WidgetAssist()
        WidgetScripts()
        WidgetGauge()
        WidgetDetails()
        WidgetActions()
        WidgetOpenPage()
    }
}

@available(iOSApplicationExtension 18.0, *)
struct WidgetsBundle18: WidgetBundle {
    init() {
        MaterialDesignIcons.register()
    }

    var body: some Widget {
        ControlScript()
        WidgetAssist()
        WidgetScripts()
        WidgetGauge()
        WidgetDetails()
        WidgetActions()
        WidgetOpenPage()
    }
}
