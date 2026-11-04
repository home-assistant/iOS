#if !os(watchOS)
import SwiftUI

/// The readings a climate-style more-info dialog leads with instead of a state header: each label
/// over its value, side by side.
///
/// Frontend counterpart: the `.current` row of `more-info-climate`, which `more-info-humidifier`
/// and `more-info-water_heater` repeat with their own readings.
public struct HAMoreInfoReadings: View {
    private let readings: [HAMoreInfoReading]

    public init(_ readings: [HAMoreInfoReading]) {
        self.readings = readings
    }

    public var body: some View {
        HStack(alignment: .top, spacing: .zero) {
            ForEach(readings) { reading in
                VStack(spacing: DesignSystem.Spaces.half) {
                    Text(reading.label)
                        .font(.system(size: 14))
                        .opacity(0.8)
                    Text(reading.value)
                        .font(.system(size: 20, weight: .medium))
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.bottom, DesignSystem.Spaces.five)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.three) {
        HAMoreInfoReadings([HAMoreInfoReading(label: "Current temperature", value: "18 °C")])
        HAMoreInfoReadings([
            HAMoreInfoReading(label: "Current temperature", value: "18 °C"),
            HAMoreInfoReading(label: "Current humidity", value: "40 %"),
        ])
    }
    .padding()
}

extension HAMoreInfoReadings: FrontendComponent {
    public static var frontendComponentName: String { "more-info-climate" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
