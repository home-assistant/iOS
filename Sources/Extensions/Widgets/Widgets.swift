import Shared
import SwiftUI
import WidgetKit

@main
enum WidgetLauncher {
    static func main() {
        if #available(iOSApplicationExtension 18.0, *) {
            WidgetsBundle18.main()
        } else {
            WidgetsBundle17.main()
        }
    }
}

@available(iOS 17.0, *)
struct WidgetsBundle17: WidgetBundle {
    var body: some Widget {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOSApplicationExtension 17.2, *) {
            HALiveActivityConfiguration()
        }
        #endif
        WidgetCommonlyUsedEntities()
        WidgetCustom()
        WidgetAssist()
        WidgetTodoList()
        WidgetOpenPage()
        WidgetGauge()
        WidgetDetails()
        WidgetSensors()
        WidgetScripts()
    }
}

@available(iOS 18.0, *)
struct WidgetsBundle18: WidgetBundle {
    var body: some Widget {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        HALiveActivityConfiguration()
        #endif

        // Controls
        ControlAssist()
        ControlLight()
        ControlSwitch()
        ControlCover()
        ControlFan()
        ControlAutomation()
        ControlScript()
        ControlScene()
        ControlButton()
        ControlOpenPage()
        ControlOpenEntity()
        ControlOpenCamera()
        // Widgets
        WidgetCommonlyUsedEntities()
        WidgetCustom()
        WidgetAssist()
        WidgetTodoList()
        WidgetOpenPage()
        WidgetGauge()
        WidgetDetails()
        WidgetSensors()
        WidgetScripts()
    }
}
