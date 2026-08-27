#if !os(watchOS)
import HAIconic
import SFSafeSymbols
import SwiftUI

/// A compact energy metric: a value with an optional direction arrow on top, and an MDI icon + label
/// below.
public struct WidgetEnergyStatView: View {
    public let icon: MaterialDesignIcons
    public let value: String
    public let unit: String?
    public let label: String
    public let direction: WidgetEnergyDirection
    public let color: Color
    public var valueFont: Font = .system(size: 20, weight: .bold, design: .rounded)

    public init(
        icon: MaterialDesignIcons,
        value: String,
        unit: String?,
        label: String,
        direction: WidgetEnergyDirection,
        color: Color,
        valueFont: Font = .system(size: 20, weight: .bold, design: .rounded)
    ) {
        self.icon = icon
        self.value = value
        self.unit = unit
        self.label = label
        self.direction = direction
        self.color = color
        self.valueFont = valueFont
    }

    public init(
        model: WidgetEnergyStatModel,
        valueFont: Font = .system(size: 20, weight: .bold, design: .rounded)
    ) {
        self.init(
            icon: model.icon,
            value: model.value,
            unit: model.unit,
            label: model.label,
            direction: model.direction,
            color: model.color,
            valueFont: valueFont
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if let symbol = direction.symbol {
                    Image(systemSymbol: symbol)
                        .font(valueFont)
                        .foregroundStyle(color)
                }
                Text(verbatim: value)
                    .font(valueFont)
                    .foregroundStyle(color)
                if let unit {
                    Text(verbatim: unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(WidgetEnergyPalette.secondaryText)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            HStack(spacing: 4) {
                Image(
                    uiImage: icon.image(ofSize: .init(width: 12, height: 12), color: .white)
                        .withRenderingMode(.alwaysTemplate)
                )
                .foregroundStyle(WidgetEnergyPalette.secondaryText)
                Text(verbatim: label)
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetEnergyPalette.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    HStack {
        WidgetEnergyStatView(
            icon: .solarPowerIcon,
            value: "12,4",
            unit: WidgetEnergyPalette.energyUnit,
            label: "Solar",
            direction: .up,
            color: WidgetEnergyPalette.solar
        )
        WidgetEnergyStatView(
            icon: .transmissionTowerIcon,
            value: "6,2",
            unit: WidgetEnergyPalette.energyUnit,
            label: "Grid",
            direction: .down,
            color: WidgetEnergyPalette.consumption
        )
    }
    .padding()
    .background(WidgetEnergyPalette.background)
}
#endif
