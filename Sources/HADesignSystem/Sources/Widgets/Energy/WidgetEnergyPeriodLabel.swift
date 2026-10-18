#if !os(watchOS)
import SwiftUI

/// The summarised period an Energy layout is showing. Doubles as a reload control once the widget
/// wraps it, so the whole header behaves the same way as the timestamp next to it.
public struct WidgetEnergyPeriodLabel: View {
    private let title: String
    private let font: Font

    public init(title: String, font: Font = .system(size: 11, weight: .semibold)) {
        self.title = title
        self.font = font
    }

    public var body: some View {
        Text(verbatim: title)
            .font(font)
            .foregroundStyle(WidgetEnergyPalette.secondaryText)
            .lineLimit(1)
    }
}

#Preview {
    WidgetEnergyPeriodLabel(title: "This week")
        .padding()
        .background(WidgetEnergyPalette.background)
}
#endif
