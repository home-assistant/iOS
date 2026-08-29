#if !os(watchOS)
import SwiftUI

/// A dial on a card. The SwiftUI counterpart of the frontend's `hui-gauge-card`.
public struct HAGaugeCard: View {
    private let name: String?
    private let value: Double
    private let min: Double
    private let max: Double
    private let valueText: String?
    private let levels: [HAGaugeLevel]

    public init(
        name: String? = nil,
        value: Double,
        min: Double = 0,
        max: Double = 100,
        valueText: String? = nil,
        levels: [HAGaugeLevel] = []
    ) {
        self.name = name
        self.value = value
        self.min = min
        self.max = max
        self.valueText = valueText
        self.levels = levels
    }

    public var body: some View {
        HACard {
            HAGauge(
                value: value,
                min: min,
                max: max,
                label: name,
                valueText: valueText,
                levels: levels,
                diameter: 160
            )
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spaces.two)
        }
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAGaugeCard(name: "Humidity", value: 64, valueText: "64 %")
        HAGaugeCard(
            name: "CPU",
            value: 72,
            levels: [
                .init(level: 0, color: .haSuccessColor),
                .init(level: 50, color: .haWarningColor),
                .init(level: 85, color: .haErrorColor),
            ]
        )
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAGaugeCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-gauge-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
