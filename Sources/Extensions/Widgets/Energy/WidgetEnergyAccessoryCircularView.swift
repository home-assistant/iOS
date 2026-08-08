import Shared
import SwiftUI
import WidgetKit

/// Lock screen circular layout. A circular accessory only has room for one figure, so it shows the
/// headline series — solar when the source preference includes it and the server reports it,
/// otherwise the grid flow.
@available(iOS 17, *)
struct WidgetEnergyAccessoryCircularView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: WidgetEnergyEntry

    private var metric: WidgetEnergyMetric? {
        entry.isConfigured ? WidgetEnergyMetric.metrics(for: entry).first : nil
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            content
        }
        .widgetBackground(Color.clear)
    }

    @ViewBuilder
    private var content: some View {
        if let metric {
            VStack(spacing: 0) {
                Text(verbatim: metric.icon.unicode)
                    .font(.custom(MaterialDesignIcons.familyName, size: 13))
                Text(verbatim: metric.value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                if let unit = metric.unit {
                    Text(verbatim: unit)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(DesignSystem.Spaces.half)
            .foregroundStyle(WidgetEnergyStyle.accessoryColor(metric.color, mode: renderingMode))
        } else {
            Text(verbatim: MaterialDesignIcons.solarPowerIcon.unicode)
                .font(.custom(MaterialDesignIcons.familyName, size: 20))
                .foregroundStyle(.secondary)
        }
    }
}

@available(iOS 17, *)
#Preview(as: .accessoryCircular) {
    WidgetEnergy()
} timeline: {
    WidgetEnergyEntry(isConfigured: true, solarGenerated: 12.4)
    WidgetEnergyEntry(isConfigured: true, solarGenerated: 12.4, livePowerSolar: 1450)
    WidgetEnergyEntry(period: .today, isConfigured: false)
}
