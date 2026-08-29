#if !os(watchOS)
import SwiftUI

/// A labelled percentage with a bar underneath, used for resource readings like disk or memory. The
/// SwiftUI counterpart of the frontend's `ha-metric`.
///
/// The bar changes colour as the reading climbs: green up to 50%, amber past it, red past 85%. Those
/// thresholds are the frontend's `target-warning` and `target-critical` classes.
public struct HAMetric: View {
    /// Formatting follows the environment's locale rather than `Locale.current`, so a caller — or a
    /// snapshot test — can pin it.
    @Environment(\.locale) private var locale
    private let heading: String
    private let value: Double

    public init(heading: String, value: Double) {
        self.heading = heading
        self.value = value
    }

    /// The frontend rounds to one decimal *before* comparing, so a reading of 85.04 stays green.
    private var roundedValue: Double {
        (value * 10).rounded() / 10
    }

    private var tint: Color {
        if roundedValue > 85 {
            .haErrorColor
        } else if roundedValue > 50 {
            .haWarningColor
        } else {
            .haSuccessColor
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            Text(heading)
                .font(DesignSystem.Font.body)
            HStack(spacing: DesignSystem.Spaces.half) {
                Text("\(roundedValue.formatted(.number.precision(.fractionLength(0 ... 1)).locale(locale))) %")
                    .font(DesignSystem.Font.subheadline)
                    .foregroundStyle(.secondary)
                    // The frontend reserves a fixed 48px so bars in a column start at the same x.
                    // A minimum rather than a fixed width, because a value that needs more room
                    // should push its bar over instead of ellipsizing to "93,8…".
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 48, alignment: .leading)
                HABar(value: value, tint: tint)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAMetric(heading: "Memory usage", value: 12.4)
        HAMetric(heading: "Disk usage", value: 67)
        HAMetric(heading: "CPU usage", value: 93.8)
    }
    .padding()
}

extension HAMetric: FrontendComponent {
    public static var frontendComponentName: String { "ha-metric" }
}

#endif
