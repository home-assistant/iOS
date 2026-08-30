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
        let density = WidgetEnergyStatDensity.stacked(count: stats.count)
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            WidgetEnergyHeaderView(
                periodTitle: periodTitle,
                date: date,
                periodControl: periodControl,
                refreshControl: refreshControl
            )

            Spacer(minLength: 0)

            if density.isCrowded {
                columns(density: density)
            } else {
                rows(density: density)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(DesignSystem.Spaces.two)
        .widgetBackground(WidgetEnergyPalette.background)
    }

    /// One or two figures, each given as much of the card's height as it wants.
    private func rows(density: WidgetEnergyStatDensity) -> some View {
        ForEach(stats) { stat in
            WidgetEnergyStatView(model: stat, density: density)
            if stat.id != stats.last?.id {
                Spacer(minLength: 0)
            }
        }
    }

    /// Three or four figures in a 2×2 block. Stacked, they would run off the bottom of the card
    /// well before `minimumScaleFactor` could rescue them; side by side there is width to spare,
    /// because an energy figure is a short number and a one-word caption.
    private func columns(density: WidgetEnergyStatDensity) -> some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: density.spacing, alignment: .leading),
                count: 2
            ),
            alignment: .leading,
            spacing: density.spacing
        ) {
            ForEach(stats) { stat in
                WidgetEnergyStatView(model: stat, density: density)
            }
        }
    }
}

@available(iOS 17, *)
#Preview("Two sources") {
    WidgetEnergySmallContentView(
        stats: WidgetEnergySampleData.stats,
        periodTitle: "Today",
        date: WidgetEnergySampleData.dayStart
    )
    .frame(width: 158, height: 158)
}

@available(iOS 17, *)
#Preview("Four sources") {
    WidgetEnergySmallContentView(
        stats: WidgetEnergySampleData.allSourceStats,
        periodTitle: "Today",
        date: WidgetEnergySampleData.dayStart
    )
    .frame(width: 158, height: 158)
}
#endif
