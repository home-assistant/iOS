#if !os(watchOS)
import SwiftUI

/// The tall, wide slider a more-info dialog leads with: ``HAControlSlider`` at the state-control
/// size, painted in the entity's colour.
///
/// Frontend counterpart: the `ha-control-slider` styling `ha-state-control-light-brightness`,
/// `ha-state-control-cover-position`, `ha-state-control-cover-tilt-position`,
/// `ha-state-control-fan-speed` and `light-color-temp-picker` share. They differ only in the mode,
/// the scale and the track, which is what this takes.
public struct HAStateControlSlider: View {
    /// What the track behind the fill looks like.
    public enum Track {
        /// The entity's colour at 20%, under a fill in the same colour.
        case tinted
        /// The cover tilt's horizontal slats in the entity's colour.
        case slats
        /// A gradient that *is* the scale, with a cursor riding it, as colour temperature has.
        case gradient(Gradient)
    }

    private let scale: HASliderScale
    private let mode: HAControlSlider.Mode
    private let track: Track
    private let color: Color
    private let showsHandle: Bool
    private let isDisabled: Bool
    private let label: String?
    @Binding private var value: Double

    public init(
        value: Binding<Double>,
        scale: HASliderScale = HASliderScale(),
        mode: HAControlSlider.Mode = .start,
        track: Track = .tinted,
        color: Color,
        showsHandle: Bool = true,
        isDisabled: Bool = false,
        label: String? = nil
    ) {
        _value = value
        self.scale = scale
        self.mode = mode
        self.track = track
        self.color = color
        self.showsHandle = showsHandle
        self.isDisabled = isDisabled
        self.label = label
    }

    private var trackGradient: Gradient? {
        switch track {
        case .tinted: nil
        case .slats: Self.slats(color: color.opacity(0.6))
        case let .gradient(gradient): gradient
        }
    }

    public var body: some View {
        HAControlSlider(
            value: $value,
            scale: scale,
            mode: mode,
            vertical: true,
            showsHandle: showsHandle,
            isDisabled: isDisabled,
            label: label,
            trackGradient: trackGradient,
            tint: color,
            trackColor: color,
            thickness: DesignSystem.StateControl.thickness,
            cornerRadius: DesignSystem.StateControl.cornerRadius
        )
        .frame(height: DesignSystem.StateControl.length)
    }

    /// `generateTiltSliderTrackBackgroundGradient`: 24 slats, each a little thicker than the one
    /// above it, so the track reads as blinds opening towards the bottom.
    static func slats(color: Color) -> Gradient {
        let count = 24
        let minStrokeWidth = 0.2
        var stops: [Gradient.Stop] = []
        for index in 0 ..< count {
            let start = Double(index) / Double(count)
            let end = start
                + (Double(index) / Double(count * count)) * (1 - minStrokeWidth)
                + minStrokeWidth / Double(count)
            if index != 0 {
                stops.append(.init(color: .clear, location: start))
            }
            stops.append(.init(color: color, location: start))
            stops.append(.init(color: color, location: end))
            stops.append(.init(color: .clear, location: end))
        }
        return Gradient(stops: stops.reversed().map { .init(color: $0.color, location: 1 - $0.location) })
    }
}

#Preview {
    HStack(spacing: DesignSystem.Spaces.two) {
        HAStateControlSlider(
            value: .constant(78),
            scale: HASliderScale(min: 1, max: 100),
            color: FrontendColors.stateLightActiveColor.color
        )
        HAStateControlSlider(
            value: .constant(50),
            mode: .end,
            color: FrontendColors.stateCoverActiveColor.color
        )
        HAStateControlSlider(
            value: .constant(50),
            mode: .cursor,
            track: .slats,
            color: FrontendColors.stateCoverActiveColor.color,
            showsHandle: false
        )
    }
    .padding()
}

extension HAStateControlSlider: FrontendComponent {
    public static var frontendComponentName: String { "ha-state-control-light-brightness" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
