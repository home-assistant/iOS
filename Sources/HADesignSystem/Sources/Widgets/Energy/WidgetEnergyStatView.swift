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
    /// How tightly the figure is drawn. Sizes the caption and icon alongside the value, so a
    /// crowded card shrinks as a whole rather than leaving an 11pt label under a 14pt number.
    public var density: WidgetEnergyStatDensity = .regular

    public init(
        icon: MaterialDesignIcons,
        value: String,
        unit: String?,
        label: String,
        direction: WidgetEnergyDirection,
        color: Color,
        density: WidgetEnergyStatDensity = .regular
    ) {
        self.icon = icon
        self.value = value
        self.unit = unit
        self.label = label
        self.direction = direction
        self.color = color
        self.density = density
    }

    public init(
        model: WidgetEnergyStatModel,
        density: WidgetEnergyStatDensity = .regular
    ) {
        self.init(
            icon: model.icon,
            value: model.value,
            unit: model.unit,
            label: model.label,
            direction: model.direction,
            color: model.color,
            density: density
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if let symbol = direction.symbol {
                    Image(systemSymbol: symbol)
                        .font(density.valueFont)
                        .foregroundStyle(color)
                }
                Text(verbatim: value)
                    .font(density.valueFont)
                    .foregroundStyle(color)
                if let unit {
                    Text(verbatim: unit)
                        .font(.system(size: density.unitSize, weight: .medium))
                        .foregroundStyle(WidgetEnergyPalette.secondaryText)
                        // Scales further than the figure it qualifies. The unit is the part that has
                        // to give when a row is tight — "kWh" stays legible small in a way a headline
                        // number doesn't, and shrinking it is what keeps the number at full size.
                        .minimumScaleFactor(0.4)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            HStack(spacing: 4) {
                Image(
                    uiImage: icon
                        .image(ofSize: .init(width: density.iconSize, height: density.iconSize), color: .white)
                        .withRenderingMode(.alwaysTemplate)
                )
                .foregroundStyle(WidgetEnergyPalette.secondaryText)
                Text(verbatim: label)
                    .font(.system(size: density.labelSize))
                    .foregroundStyle(WidgetEnergyPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

@available(iOS 17, *)
#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
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

        // The four-source home, at the density a single row has to draw it.
        HStack(spacing: WidgetEnergyStatDensity.dense.spacing) {
            ForEach(WidgetEnergySampleData.allSourceStats) { stat in
                WidgetEnergyStatView(model: stat, density: .dense)
            }
        }
    }
    .padding()
    .background(WidgetEnergyPalette.background)
}
#endif
