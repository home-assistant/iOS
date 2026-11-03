#if !os(watchOS)
import SwiftUI

private struct WidgetToggleColorEnvironmentKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

public extension EnvironmentValues {
    var widgetToggleColor: Color? {
        get { self[WidgetToggleColorEnvironmentKey.self] }
        set { self[WidgetToggleColorEnvironmentKey.self] = newValue }
    }
}
#endif
