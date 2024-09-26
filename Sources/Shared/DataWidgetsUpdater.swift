import Foundation
import WidgetKit

#if os(iOS)
public enum DataWidgetsUpdater {
    public static func update() {
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadAllControls()
        }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.gauge.rawValue)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.details.rawValue)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.detailsTable.rawValue)
    }
}
#endif
