import SwiftUI

/// A specialized vertical slider for brightness control
@available(iOS 26.0, *)
struct BrightnessSlider: View {
    @Binding var brightness: Double
    let color: Color
    let onEditingChanged: ((Bool) -> Void)?

    init(
        brightness: Binding<Double>,
        color: Color = .yellow,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._brightness = brightness
        self.color = color
        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        VerticalSlider(
            value: $brightness,
            in: 0 ... 100,
            step: 1,
            icon: .sunMaxFill,
            tint: color,
            onEditingChanged: onEditingChanged
        )
    }
}
