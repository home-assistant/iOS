import SwiftUI

@available(iOS 26.0, *)
/// A vertical slider control with customizable appearance
struct VerticalSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double?
    let icon: String?
    let tint: Color
    let trackWidth: CGFloat
    let thumbSize: CGFloat
    let onEditingChanged: ((Bool) -> Void)?

    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0

    init(
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0 ... 100,
        step: Double? = nil,
        icon: String? = nil,
        tint: Color = .accentColor,
        trackWidth: CGFloat = 44,
        thumbSize: CGFloat = 28,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.icon = icon
        self.tint = tint
        self.trackWidth = trackWidth
        self.thumbSize = thumbSize
        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background track
                Capsule()
                    .fill(Color(uiColor: .secondarySystemFill))
                    .frame(width: trackWidth)

                // Filled track
                Capsule()
                    .fill(tint.gradient)
                    .frame(
                        width: trackWidth,
                        height: filledHeight(in: geometry.size.height)
                    )

                // Icon at bottom (optional)
                if let icon {
                    VStack {
                        Spacer()
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(tint)
                            .padding(.bottom, 12)
                    }
                }

                // Thumb
                thumb
                    .position(
                        x: geometry.size.width / 2,
                        y: thumbPosition(in: geometry.size.height)
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged?(true)
                        }

                        let newValue = calculateValue(
                            from: gesture.location.y,
                            in: geometry.size.height
                        )

                        if let step {
                            value = round(newValue / step) * step
                        } else {
                            value = newValue
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEditingChanged?(false)
                    }
            )
        }
    }

    // MARK: - Subviews

    private var thumb: some View {
        ZStack {
            Circle()
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            Circle()
                .strokeBorder(tint, lineWidth: 2)

            if isDragging {
                Circle()
                    .fill(tint.opacity(0.2))
                    .scaleEffect(1.3)
            }
        }
        .frame(width: thumbSize, height: thumbSize)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
    }

    // MARK: - Calculations

    private func normalizedValue() -> Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private func thumbPosition(in height: CGFloat) -> CGFloat {
        let normalized = normalizedValue()
        let availableHeight = height - thumbSize
        // Inverted: 0 is at bottom, 1 is at top
        return availableHeight - (CGFloat(normalized) * availableHeight) + (thumbSize / 2)
    }

    private func filledHeight(in height: CGFloat) -> CGFloat {
        let normalized = normalizedValue()
        return CGFloat(normalized) * height
    }

    private func calculateValue(from yPosition: CGFloat, in height: CGFloat) -> Double {
        let availableHeight = height - thumbSize
        let clampedY = max(thumbSize / 2, min(height - thumbSize / 2, yPosition))

        // Inverted calculation: top is max, bottom is min
        let normalized = 1.0 - Double((clampedY - thumbSize / 2) / availableHeight)
        let newValue = range.lowerBound + (normalized * (range.upperBound - range.lowerBound))

        return max(range.lowerBound, min(range.upperBound, newValue))
    }
}

// MARK: - Brightness Slider

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
            icon: "sun.max.fill",
            tint: color,
            trackWidth: 44,
            thumbSize: 28,
            onEditingChanged: onEditingChanged
        )
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Vertical Slider") {
    @Previewable @State var value: Double = 50

    VStack(spacing: 40) {
        HStack(spacing: 40) {
            VerticalSlider(
                value: $value,
                tint: .blue
            )
            .frame(width: 60, height: 300)

            VerticalSlider(
                value: $value,
                icon: "speaker.wave.3.fill",
                tint: .purple
            )
            .frame(width: 60, height: 300)

            BrightnessSlider(
                brightness: $value,
                color: .orange
            )
            .frame(width: 60, height: 300)
        }

        Text("Value: \(Int(value))")
            .font(.headline)
    }
    .padding()
}
