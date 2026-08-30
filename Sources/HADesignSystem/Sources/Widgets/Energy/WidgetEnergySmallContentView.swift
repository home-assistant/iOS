#if !os(watchOS)
import SwiftUI

/// Compact card showing solar generation and grid flow. Which figures those are — live power when
/// power sensors report it, the period's totals otherwise — is settled before they get here.
@available(iOS 17, *)
public struct WidgetEnergySmallContentView: View {
    /// Wraps a rendered label in the control that runs it.
    public typealias ControlContent = (AnyView) -> AnyView

    private let stats: [WidgetEnergyStatModel]
    private let periodTitle: String
    private let date: Date
    private let periodControl: ControlContent
    private let refreshControl: ControlContent

    public init(
        stats: [WidgetEnergyStatModel],
        periodTitle: String,
        date: Date,
        periodControl: @escaping ControlContent = { $0 },
        refreshControl: @escaping ControlContent = { $0 }
    ) {
        self.stats = stats
        self.periodTitle = periodTitle
        self.date = date
        self.periodControl = periodControl
        self.refreshControl = refreshControl
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            WidgetEnergyHeaderView(
                periodTitle: periodTitle,
                date: date,
                periodControl: periodControl,
                refreshControl: refreshControl
            )

            Spacer(minLength: 0)

            ForEach(stats) { stat in
                WidgetEnergyStatView(
                    model: stat,
                    valueFont: .system(
                        size: stats.count == 1 ? 34 : 22,
                        weight: .bold,
                        design: .rounded
                    )
                )
                if stat.id != stats.last?.id {
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(DesignSystem.Spaces.two)
        .widgetBackground(WidgetEnergyPalette.background)
    }
}

@available(iOS 17, *)
#Preview {
    WidgetEnergySmallContentView(
        stats: WidgetEnergySampleData.stats,
        periodTitle: "Today",
        date: WidgetEnergySampleData.dayStart
    )
    .frame(width: 158, height: 158)
}
#endif
