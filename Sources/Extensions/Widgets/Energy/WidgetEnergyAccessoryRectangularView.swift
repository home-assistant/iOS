import Shared
import SwiftUI
import WidgetKit

/// Lock screen rectangular layout: the period title, then one row per configured energy series.
@available(iOS 17, *)
struct WidgetEnergyAccessoryRectangularView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: WidgetEnergyEntry

    var body: some View {
        let metrics = entry.isConfigured ? WidgetEnergyMetric.metrics(for: entry) : []
        VStack(alignment: .leading, spacing: 1) {
            if metrics.isEmpty {
                // No period header here: there is no figure for it to caption.
                Text(WidgetEnergyStyle.emptyStateText(isConfigured: entry.isConfigured, loadFailed: entry.loadFailed))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            } else {
                Text(entry.period.displayTitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ForEach(metrics) { metric in
                    row(for: metric)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetBackground(Color.clear)
    }

    private func row(for metric: WidgetEnergyMetric) -> some View {
        HStack(spacing: DesignSystem.Spaces.half) {
            Text(verbatim: metric.icon.unicode)
                .font(.custom(MaterialDesignIcons.familyName, size: 12))
            Text(verbatim: metric.value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            if let unit = metric.unit {
                Text(verbatim: unit)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(WidgetEnergyStyle.accessoryColor(metric.color, mode: renderingMode))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

@available(iOS 17, *)
#Preview(as: .accessoryRectangular) {
    WidgetEnergy()
} timeline: {
    WidgetEnergyEntry(
        isConfigured: true,
        gridConsumed: 6.2,
        gridReturned: 10.5,
        solarGenerated: 12.4
    )
    WidgetEnergyEntry(
        isConfigured: true,
        solarGenerated: 12.4,
        livePowerGrid: -180,
        livePowerSolar: 250
    )
    WidgetEnergyEntry(period: .today, isConfigured: false)
}
