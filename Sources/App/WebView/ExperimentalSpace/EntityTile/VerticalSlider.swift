import SFSafeSymbols
import SwiftUI

@available(iOS 26.0, *)
/// Shape options for the vertical slider track
enum VerticalSliderShape {
    case capsule
    case roundedRectangle(cornerRadius: CGFloat)
    case rectangle

    @ViewBuilder
    func shape(_ content: some ShapeStyle) -> some View {
        switch self {
        case .capsule:
            Capsule().fill(content)
        case let .roundedRectangle(radius):
            RoundedRectangle(cornerRadius: radius).fill(content)
        case .rectangle:
            Rectangle().fill(content)
        }
    }

    func clipShape() -> AnyShape {
        switch self {
        case .capsule:
            AnyShape(Capsule())
        case let .roundedRectangle(radius):
            AnyShape(RoundedRectangle(cornerRadius: radius))
        case .rectangle:
            AnyShape(Rectangle())
        }
    }
}

@available(iOS 26.0, *)
/// A vertical slider control with customizable appearance
struct VerticalSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double?
    let icon: SFSymbol?
    let tint: Color
    let trackWidth: CGFloat
    let thumbSize: CGFloat
    let showThumb: Bool
    let shape: VerticalSliderShape
    let onEditingChanged: ((Bool) -> Void)?

    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0

    init(
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0 ... 100,
        step: Double? = nil,
        icon: SFSymbol? = nil,
        tint: Color = .accentColor,
        trackWidth: CGFloat = 84,
        thumbSize: CGFloat = 28,
        showThumb: Bool = false,
        shape: VerticalSliderShape = .capsule,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.icon = icon
        self.tint = tint
        self.trackWidth = trackWidth
        self.thumbSize = thumbSize
        self.showThumb = showThumb
        self.shape = shape
        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background track with filled track masked inside
                Group {
                    shape.shape(Color(uiColor: .secondarySystemFill))
                }
                .frame(width: trackWidth)
                .overlay(alignment: .bottom) {
                    // Filled track
                    Group {
                        shape.shape(tint.gradient)
                    }
                    .frame(height: filledHeight(in: geometry.size.height))
                }
                .clipShape(shape.clipShape())

                // Icon at bottom (optional)
                if let icon {
                    VStack {
                        Spacer()
                        Image(systemSymbol: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(tint)
                            .padding(.bottom, 12)
                    }
                }

                // Thumb
                if showThumb {
                    thumb
                        .position(
                            x: geometry.size.width / 2,
                            y: thumbPosition(in: geometry.size.height)
                        )
                }
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

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Vertical Slider") {
    @Previewable @State var value: Double = 50

    VStack {
        HStack {
            VerticalSlider(
                value: $value,
                tint: .blue,
                shape: .capsule
            )
            .frame(height: 300)

            VerticalSlider(
                value: $value,
                icon: .speakerWave3,
                tint: .purple,
                shape: .roundedRectangle(cornerRadius: 12)
            )
            .frame(height: 300)

            VerticalSlider(
                value: $value,
                icon: .speakerWave3,
                tint: .green,
                showThumb: false,
                shape: .rectangle
            )
            .frame(height: 300)
        }

        Text("Value: \(Int(value))")
            .font(.headline)
    }
    .padding()
}
