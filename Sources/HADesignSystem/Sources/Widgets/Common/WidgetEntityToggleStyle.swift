#if !os(watchOS)
import SwiftUI

public struct WidgetEntityToggleStyle: ToggleStyle {
    private let initialIsOn: Bool
    private let onColor: Color
    private let offColor: Color

    public init(initialIsOn: Bool, onColor: Color, offColor: Color) {
        self.initialIsOn = initialIsOn
        self.onColor = onColor
        self.offColor = offColor
    }

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
                .environment(\.widgetToggleColor, configuration.isOn ? onColor : offColor)
                .opacity(configuration.isOn ? 1 : 0.65)
        }
        .buttonStyle(.plain)
        .disabled(configuration.isOn != initialIsOn)
    }
}
#endif
