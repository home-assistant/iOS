import SwiftUI
import WidgetKit

#if !WIDGET_EXTENSION
extension WidgetFamily: @retroactive EnvironmentKey {
    public static var defaultValue: WidgetFamily = .systemMedium
}

extension EnvironmentValues {
    var widgetFamily: WidgetFamily {
        get { self[WidgetFamily.self] }
        set { self[WidgetFamily.self] = newValue }
    }
}
#endif
