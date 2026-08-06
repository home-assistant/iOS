import Shared
import SwiftUI
import WidgetKit

/// Compact card showing solar generation and grid flow. Prefers live instantaneous power (W) when
/// power sensors are configured, otherwise falls back to the period's energy totals (kWh).
@available(iOS 17, *)
struct WidgetEnergySmallView: View {
    let entry: WidgetEnergyEntry

    private struct Metric: Identifiable {
        let id = UUID()
        let icon: MaterialDesignIcons
        let value: String
        let unit: String?
        let label: String
        let direction: WidgetEnergyStyle.Direction
        let color: Color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            HStack {
                Text(entry.period.displayTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WidgetEnergyStyle.secondaryText)
                Spacer()
                Text(entry.date, style: .time)
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetEnergyStyle.secondaryText)
            }

            Spacer(minLength: 0)

            if metrics.isEmpty {
                Text(L10n.Widgets.Energy.noData)
                    .font(.footnote)
                    .foregroundStyle(WidgetEnergyStyle.secondaryText)
            } else {
                ForEach(metrics) { metric in
                    WidgetEnergyStatView(
                        icon: metric.icon,
                        value: metric.value,
                        unit: metric.unit,
                        label: metric.label,
                        direction: metric.direction,
                        color: metric.color,
                        valueFont: .system(
                            size: metrics.count == 1 ? 34 : 22,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    if metric.id != metrics.last?.id {
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(DesignSystem.Spaces.two)
        .widgetBackground(WidgetEnergyStyle.background)
    }

    private var metrics: [Metric] {
        [
            entry.source.showsSolar ? solarMetric : nil,
            entry.source.showsGrid ? gridMetric : nil,
        ].compactMap { $0 }
    }

    private var solarMetric: Metric? {
        if let watts = entry.livePowerSolar {
            let power = WidgetEnergyStyle.power(watts)
            return Metric(
                icon: .solarPowerIcon,
                value: power.value,
                unit: power.unit,
                label: L10n.Widgets.Energy.solar,
                direction: .up,
                color: WidgetEnergyStyle.solar
            )
        }
        if let kWh = entry.solarGenerated {
            return Metric(
                icon: .solarPowerIcon,
                value: WidgetEnergyStyle.energy(kWh),
                unit: WidgetEnergyStyle.energyUnit,
                label: L10n.Widgets.Energy.solar,
                direction: .up,
                color: WidgetEnergyStyle.solar
            )
        }
        return nil
    }

    private var gridMetric: Metric? {
        if let watts = entry.livePowerGrid {
            let consuming = watts > 0
            let power = WidgetEnergyStyle.power(watts)
            return Metric(
                icon: .transmissionTowerIcon,
                value: power.value,
                unit: power.unit,
                label: L10n.Widgets.Energy.grid,
                direction: consuming ? .down : .up,
                color: WidgetEnergyStyle.consumption
            )
        }
        if let net = entry.gridNet {
            return Metric(
                icon: .transmissionTowerIcon,
                value: WidgetEnergyStyle.energy(net),
                unit: WidgetEnergyStyle.energyUnit,
                label: L10n.Widgets.Energy.grid,
                direction: net >= 0 ? .up : .down,
                color: WidgetEnergyStyle.consumption
            )
        }
        return nil
    }
}

@available(iOS 17, *)
#Preview(as: .systemSmall) {
    WidgetEnergy()
} timeline: {
    WidgetEnergyEntry(
        isConfigured: true,
        solarGenerated: 12.4,
        livePowerGrid: -180,
        livePowerSolar: 250
    )
}
