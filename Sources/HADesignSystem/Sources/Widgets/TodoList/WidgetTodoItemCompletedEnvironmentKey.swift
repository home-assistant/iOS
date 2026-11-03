#if !os(watchOS)
import SwiftUI

private struct WidgetTodoItemCompletedEnvironmentKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    var widgetTodoItemCompleted: Bool {
        get { self[WidgetTodoItemCompletedEnvironmentKey.self] }
        set { self[WidgetTodoItemCompletedEnvironmentKey.self] = newValue }
    }
}
#endif
