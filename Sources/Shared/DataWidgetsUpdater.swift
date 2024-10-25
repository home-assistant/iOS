import Foundation
import WidgetKit

#if os(iOS) || os(macOS)
public enum DataWidgetsUpdater {
    public static func update() {
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadAllControls()
        }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.gauge.rawValue)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.details.rawValue)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.sensors.rawValue)
    }
}
#endif
