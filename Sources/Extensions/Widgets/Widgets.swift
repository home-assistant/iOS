import Shared
import SwiftUI
import WidgetKit

@main
struct Widgets: WidgetBundle {
    init() {
        MaterialDesignIcons.register()
    }

    @WidgetBundleBuilder
    var body: some Widget {
        widgets
    }

    // Workaround for variable WidgetBundle: https://www.avanderlee.com/swiftui/variable-widgetbundle-configuration/
    private var widgets: some Widget {
        if #available(iOS 17, *) {
            return WidgetBundleBuilder.buildBlock(
                iOS17Widgets
            )
        } else {
            return WidgetBundleBuilder.buildBlock(
                legacyWidgets
            )
        }
    }

    @available(iOS 17, *)
    @WidgetBundleBuilder
    private var iOS17Widgets: some Widget {
        WidgetAssist()
        WidgetScripts()
        WidgetGauge()
        WidgetDetails()
        WidgetActions()
        WidgetOpenPage()
    }

    @WidgetBundleBuilder
    private var legacyWidgets: some Widget {
        WidgetAssist()
        LegacyWidgetActions()
        WidgetOpenPage()
    }
}
