#if !os(watchOS)
import SwiftUI

/// A plain horizontal progress bar: a filled portion over a recessed track. The SwiftUI counterpart
/// of the frontend's `ha-bar`.
///
/// The value is clamped into `min...max` before it is turned into a proportion, so a reading that
/// overshoots its range draws full rather than spilling past the track — the frontend's `normalize`.
public struct HABar: View {
    private let value: Double
    private let min: Double
    private let max: Double
    private let tint: Color
    private let track: Color

    /// - Parameters:
    ///   - tint: The filled portion. Defaults to the brand colour, `ha-bar`'s `--primary-color`.
    ///   - track: The unfilled remainder, `ha-bar`'s `--secondary-background-color`.
    public init(
        value: Double,
        min: Double = 0,
        max: Double = 100,
        tint: Color = .haPrimary,
        track: Color = .haSecondaryBackground
    ) {
        self.value = value
        self.min = min
        self.max = max
        self.tint = tint
        self.track = track
    }

    /// How much of the track is filled, `0...1`. A zero-width range reads as empty rather than
    /// dividing by zero.
    private var fraction: Double {
        guard max > min else { return 0 }
        return (value.clamped(to: min ... max) - min) / (max - min)
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(track)
                Rectangle()
                    .fill(tint)
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 12)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.half))
        .accessibilityElement()
        .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HABar(value: 0)
        HABar(value: 35)
        HABar(value: 100)
        HABar(value: 150, tint: .haErrorColor)
        HABar(value: 12, min: 10, max: 20, tint: .haSuccessColor)
    }
    .padding()
}

extension HABar: FrontendComponent {
    public static var frontendComponentName: String { "ha-bar" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
