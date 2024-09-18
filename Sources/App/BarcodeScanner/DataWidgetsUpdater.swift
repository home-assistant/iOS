import Foundation
import Shared
import WidgetKit

enum DataWidgetsUpdater {
    static func update() {
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadAllControls()
        }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.gauge.rawValue)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.details.rawValue)
    }
}
