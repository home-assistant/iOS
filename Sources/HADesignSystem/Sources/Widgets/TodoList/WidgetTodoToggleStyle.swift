#if !os(watchOS)
import SwiftUI

public struct WidgetTodoToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
                .environment(\.widgetTodoItemCompleted, configuration.isOn)
        }
        .buttonStyle(.plain)
        .disabled(configuration.isOn)
    }
}
#endif
