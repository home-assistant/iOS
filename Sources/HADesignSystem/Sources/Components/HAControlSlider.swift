#if !os(watchOS)
import SwiftUI

/// The chunky track-and-bar slider the dashboard uses for brightness, volume and position. The
/// SwiftUI counterpart of the frontend's `ha-control-slider`.
///
/// Dragging anywhere on the track moves the value — the whole bar is the control, not a thumb on it.
/// The value maths lives in ``HASliderScale`` so it can be tested apart from the drawing.
public struct HAControlSlider: View {
    /// How the filled part of the track is drawn, the frontend's `SliderMode`.
    public enum Mode: String, CaseIterable, Sendable {
        /// Fills from the start of the track to the value. The default.
        case start
        /// Fills from the end of the track back to the value, for a value read as a remainder.
        case end
        /// Draws a marker at the value instead of a fill, for a position with no natural zero.
        case cursor
    }

    private let scale: HASliderScale
    private let mode: Mode
    private let vertical: Bool
    private let showsHandle: Bool
    private let isDisabled: Bool
    private let label: String?
    private let trackGradient: Gradient?
    @Binding private var value: Double

    /// - Parameters:
    ///   - showsHandle: Draws a white grip inside the bar's leading edge, for a slider whose fill
    ///     colour is close to its track.
    ///   - trackGradient: Paints the track with a gradient instead of the flat recess, and drops the
    ///     fill. This is what the light colour-temperature feature is: the track itself is the
    ///     scale, from warm to cool, and a cursor marks where on it you are.
    public init(
        value: Binding<Double>,
        scale: HASliderScale = HASliderScale(),
        mode: Mode = .start,
        vertical: Bool = false,
        showsHandle: Bool = false,
        isDisabled: Bool = false,
        label: String? = nil,
        trackGradient: Gradient? = nil
    ) {
        _value = value
        self.scale = scale
        self.mode = mode
        self.vertical = vertical
        self.showsHandle = showsHandle
        self.isDisabled = isDisabled
        self.label = label
        self.trackGradient = trackGradient
    }

    private static let thickness: CGFloat = 40
    private static let cornerRadius = DesignSystem.CornerRadius.oneAndHalf
    private static let cursorThickness: CGFloat = 14

    public var body: some View {
        GeometryReader { proxy in
            // Vertical sliders fill upwards, so the fraction is measured from the bottom.
            let length = vertical ? proxy.size.height : proxy.size.width
            let fraction = scale.percentage(for: value)

            ZStack(alignment: vertical ? .bottom : .leading) {
                if let trackGradient {
                    LinearGradient(
                        gradient: trackGradient,
                        startPoint: vertical ? .bottom : .leading,
                        endPoint: vertical ? .top : .trailing
                    )
                } else {
                    Rectangle()
                        .fill(Color.haDisabled.opacity(0.2))
                }
                // A gradient track *is* the scale, so only the cursor marks the value on it.
                if trackGradient == nil || mode == .cursor {
                    fill(length: length, fraction: fraction)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard !isDisabled else { return }
                        let position = vertical
                            ? 1 - (drag.location.y / length)
                            : drag.location.x / length
                        value = scale.stepped(
                            scale.value(atPercentage: Swift.min(Swift.max(position, 0), 1))
                        )
                    }
            )
        }
        .frame(
            width: vertical ? Self.thickness : nil,
            height: vertical ? nil : Self.thickness
        )
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityElement()
        .accessibilityLabel(optional: label)
        .accessibilityValue(Text("\(scale.stepped(value).formatted())"))
        .accessibilityAdjustableAction { direction in
            guard !isDisabled else { return }
            switch direction {
            case .increment: value = scale.stepped(value + scale.step)
            case .decrement: value = scale.stepped(value - scale.step)
            @unknown default: break
            }
        }
    }

    @ViewBuilder
    private func fill(length: CGFloat, fraction: Double) -> some View {
        switch mode {
        case .start, .end:
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .fill(Color.haPrimary)
                // The grip belongs to the bar, so it is overlaid before the alignment frame below —
                // on that frame it would land at the end of the whole track instead.
                .overlay(alignment: handleAlignment) {
                    if showsHandle {
                        Capsule()
                            .fill(.white)
                            .frame(
                                width: vertical ? Self.thickness / 2 : 4,
                                height: vertical ? 4 : Self.thickness / 2
                            )
                            .padding(vertical ? .vertical : .horizontal, DesignSystem.Spaces.half)
                    }
                }
                .frame(
                    width: vertical ? nil : length * fraction,
                    height: vertical ? length * fraction : nil
                )
                // `.end` fills back from the far edge, so the same fraction is anchored the other way.
                .frame(
                    maxWidth: vertical ? nil : .infinity,
                    maxHeight: vertical ? .infinity : nil,
                    alignment: endAlignment
                )
        case .cursor:
            // A white grip with a dark bar through it, riding the track — checked against the
            // rendered `ha-control-slider`, whose cursor reads as a scrubber rather than as a
            // short length of fill.
            Capsule()
                .fill(.white)
                .overlay {
                    Capsule()
                        .fill(Color(uiColor: .label))
                        .frame(
                            width: vertical ? Self.thickness / 4 : 2,
                            height: vertical ? 2 : Self.thickness / 4
                        )
                }
                .frame(
                    width: vertical ? Self.thickness - DesignSystem.Spaces.one : Self.cursorThickness,
                    height: vertical ? Self.cursorThickness : Self.thickness - DesignSystem.Spaces.one
                )
                .offset(
                    x: vertical ? 0 : (length - Self.cursorThickness) * fraction,
                    y: vertical ? -(length - Self.cursorThickness) * fraction : 0
                )
                .frame(
                    maxWidth: vertical ? nil : .infinity,
                    maxHeight: vertical ? .infinity : nil,
                    alignment: vertical ? .bottom : .leading
                )
        }
    }

    private var endAlignment: Alignment {
        switch (mode, vertical) {
        case (.end, false): .trailing
        case (.end, true): .top
        case (_, false): .leading
        case (_, true): .bottom
        }
    }

    private var handleAlignment: Alignment {
        switch (mode, vertical) {
        case (.end, false): .leading
        case (.end, true): .bottom
        case (_, false): .trailing
        case (_, true): .top
        }
    }
}

#Preview("Modes") {
    VStack(spacing: DesignSystem.Spaces.three) {
        ForEach(HAControlSlider.Mode.allCases, id: \.rawValue) { mode in
            HAControlSlider(value: .constant(60), mode: mode, label: mode.rawValue)
        }
    }
    .padding()
}

#Preview("Options") {
    VStack(spacing: DesignSystem.Spaces.three) {
        HAControlSlider(value: .constant(60), showsHandle: true, label: "With handle")
        HAControlSlider(value: .constant(60), isDisabled: true, label: "Disabled")
        HAControlSlider(
            value: .constant(60),
            scale: HASliderScale(inverted: true),
            label: "Inverted"
        )
        HStack(spacing: DesignSystem.Spaces.three) {
            HAControlSlider(value: .constant(60), vertical: true, label: "Vertical")
            HAControlSlider(value: .constant(60), mode: .end, vertical: true, label: "Vertical end")
        }
        .frame(height: 160)
    }
    .padding()
}

extension HAControlSlider: FrontendComponent {
    public static var frontendComponentName: String { "ha-control-slider" }
}

#endif
