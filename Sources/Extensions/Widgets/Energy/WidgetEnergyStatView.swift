import SFSafeSymbols
import Shared
import SwiftUI

/// A compact energy metric: a value with an optional direction arrow on top, and an MDI icon + label below.
struct WidgetEnergyStatView: View {
    let icon: MaterialDesignIcons
    let value: String
    let unit: String?
    let label: String
    let direction: WidgetEnergyStyle.Direction
    let color: Color
    var valueFont: Font = .system(size: 20, weight: .bold, design: .rounded)

    var body: some View {
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
                        .foregroundStyle(WidgetEnergyStyle.secondaryText)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            HStack(spacing: 4) {
                Image(
                    uiImage: icon.image(ofSize: .init(width: 12, height: 12), color: .white)
                        .withRenderingMode(.alwaysTemplate)
                )
                .foregroundStyle(WidgetEnergyStyle.secondaryText)
                Text(verbatim: label)
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetEnergyStyle.secondaryText)
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
            unit: WidgetEnergyStyle.energyUnit,
            label: "Solar",
            direction: .up,
            color: WidgetEnergyStyle.solar
        )
        WidgetEnergyStatView(
            icon: .transmissionTowerIcon,
            value: "6,2",
            unit: WidgetEnergyStyle.energyUnit,
            label: "Grid",
            direction: .down,
            color: WidgetEnergyStyle.consumption
        )
    }
    .padding()
    .background(WidgetEnergyStyle.background)
}
