import Shared
import SwiftUI
import WidgetKit

@main
enum WidgetLauncher {
    static func main() {
        // Control Center controls, which the newer bundle adds, reached the Mac in macOS 26.
        if #available(iOSApplicationExtension 18.0, macOSApplicationExtension 26.0, *) {
            WidgetsBundle18.main()
        } else {
            WidgetsBundle17.main()
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct WidgetsBundle17: WidgetBundle {
    init() {
        MaterialDesignIcons.register()
    }

    var body: some Widget {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOSApplicationExtension 17.2, *) {
            HALiveActivityConfiguration()
        }
        #endif
        WidgetEntities()
        WidgetAreas()
        WidgetEnergy()
        WidgetCommonlyUsedEntities()
        WidgetCalendar()
        WidgetOpenPage()
        WidgetCustom()
        WidgetTodoList()
        WidgetAssist()
        WidgetGauge()
        #if !os(macOS)
        WidgetDetails()
        #endif
        WidgetSensors()
        WidgetScripts()
    }
}

@available(iOS 18.0, macOS 26.0, *)
struct WidgetsBundle18: WidgetBundle {
    init() {
        MaterialDesignIcons.register()
    }

    var body: some Widget {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        HALiveActivityConfigurationSupplemental()
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
        WidgetEntities()
        WidgetAreas()
        WidgetEnergy()
        WidgetCommonlyUsedEntities()
        WidgetCalendar()
        WidgetOpenPage()
        WidgetCustom()
        WidgetTodoList()
        WidgetAssist()
        WidgetGauge()
        #if !os(macOS)
        WidgetDetails()
        #endif
        WidgetSensors()
        WidgetScripts()
    }
}
