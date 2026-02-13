import Foundation
import WidgetKit

#if os(iOS) || os(macOS)
public enum DataWidgetsUpdater {
    /// Updates widgets and control center controls
    public static func update() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.gauge.rawValue)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.details.rawValue)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.sensors.rawValue)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.custom.rawValue)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.todoList.rawValue)
        DataWidgetsUpdater.updateControlCenterControls()
    }

    public static func updateControlCenterControls() {
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadAllControls()
        }
    }
}
#endif
