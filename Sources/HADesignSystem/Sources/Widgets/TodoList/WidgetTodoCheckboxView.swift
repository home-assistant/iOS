#if !os(watchOS)
import SFSafeSymbols
import SwiftUI

public struct WidgetTodoCheckboxView: View {
    @Environment(\.widgetTodoItemCompleted) private var isCompleted

    public init() {}

    public var body: some View {
        Text(Image(systemSymbol: isCompleted ? .checkmarkCircleFill : .circle))
    }
}

#Preview {
    Toggle(isOn: .constant(false)) {
        WidgetTodoCheckboxView()
            .font(.body)
            .foregroundStyle(.haPrimary)
    }
    .toggleStyle(WidgetTodoToggleStyle())
}
#endif
