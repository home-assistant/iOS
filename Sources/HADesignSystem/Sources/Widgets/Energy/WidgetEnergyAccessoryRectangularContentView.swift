#if !os(watchOS)
import HAIconic
import SwiftUI
import WidgetKit

/// Lock screen rectangular layout: the period title, then one row per configured energy series.
@available(iOS 17, *)
public struct WidgetEnergyAccessoryRectangularContentView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    private let stats: [WidgetEnergyStatModel]
    private let periodTitle: String
    /// What to say when there is nothing to report — which is where "not configured" and "no data"
    /// are told apart, so the widget decides the wording.
    private let emptyText: String

    public init(stats: [WidgetEnergyStatModel], periodTitle: String, emptyText: String) {
        self.stats = stats
        self.periodTitle = periodTitle
        self.emptyText = emptyText
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if stats.isEmpty {
                // No period header here: there is no figure for it to caption.
                Text(verbatim: emptyText)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            } else {
                Text(verbatim: periodTitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ForEach(stats) { stat in
                    row(for: stat)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetBackground(Color.clear)
    }

    private func row(for stat: WidgetEnergyStatModel) -> some View {
        HStack(spacing: DesignSystem.Spaces.half) {
            Text(verbatim: stat.icon.unicode)
                .font(.custom(MaterialDesignIcons.familyName, size: 12))
            Text(verbatim: stat.value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            if let unit = stat.unit {
                Text(verbatim: unit)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(WidgetEnergyPalette.accessoryColor(stat.color, mode: renderingMode))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

@available(iOS 17, *)
#Preview {
    WidgetEnergyAccessoryRectangularContentView(
        stats: WidgetEnergySampleData.stats,
        periodTitle: "Today",
        emptyText: "No energy data"
    )
    .frame(width: 160, height: 72)
}
#endif
