#if !os(watchOS)
import Foundation
import HAIconic
import SwiftUI

/// Medium/large layout: period totals for solar and grid, monetary cost, and the net-grid chart.
@available(iOS 17, *)
public struct WidgetEnergyMediumContentView: View {
    /// Wraps a rendered label in the control that runs it.
    public typealias ControlContent = (AnyView) -> AnyView

    private let stats: [WidgetEnergyStatModel]
    /// The period's cost, already formatted. `nil` drops the whole cost row, which is what a home
    /// with no grid series — or no tariff — wants.
    private let costText: String?
    private let periodTitle: String
    private let date: Date
    private let chartPoints: [WidgetEnergyChartPoint]
    private let showsGrid: Bool
    private let showsSolar: Bool
    private let isDaily: Bool
    private let dayStride: Int
    private let periodRange: (start: Date, end: Date)
    private let periodControl: ControlContent
    private let refreshControl: ControlContent

    public init(
        stats: [WidgetEnergyStatModel],
        costText: String? = nil,
        periodTitle: String,
        date: Date,
        chartPoints: [WidgetEnergyChartPoint],
        showsGrid: Bool = true,
        showsSolar: Bool = true,
        isDaily: Bool = false,
        dayStride: Int = 1,
        periodRange: (start: Date, end: Date),
        periodControl: @escaping ControlContent = { $0 },
        refreshControl: @escaping ControlContent = { $0 }
    ) {
        self.stats = stats
        self.costText = costText
        self.periodTitle = periodTitle
        self.date = date
        self.chartPoints = chartPoints
        self.showsGrid = showsGrid
        self.showsSolar = showsSolar
        self.isDaily = isDaily
        self.dayStride = dayStride
        self.periodRange = periodRange
        self.periodControl = periodControl
        self.refreshControl = refreshControl
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
                ForEach(stats) { stat in
                    WidgetEnergyStatView(model: stat)
                }

                Spacer(minLength: 0)

                topTrailingAccessory
            }

            // Drawn even with no points, so the period reads as "nothing yet" rather than as a card
            // that lost its chart.
            WidgetEnergyChartView(
                points: chartPoints,
                showsGrid: showsGrid,
                showsSolar: showsSolar,
                isDaily: isDaily,
                dayStride: dayStride,
                periodRange: periodRange
            )
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DesignSystem.Spaces.two)
        .widgetBackground(WidgetEnergyPalette.background)
    }

    /// The period cost when available, followed by the summarised period and the reload button
    /// carrying the time the entry was refreshed. Replaces the shared header on these families, which
    /// have room for it on the trailing edge of the stats row.
    private var topTrailingAccessory: some View {
        VStack(alignment: .trailing, spacing: DesignSystem.Spaces.half) {
            if let costText {
                HStack(spacing: DesignSystem.Spaces.half) {
                    Text(verbatim: costText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WidgetEnergyPalette.primaryText)
                    Image(
                        uiImage: MaterialDesignIcons.transmissionTowerIcon
                            .image(ofSize: .init(width: 16, height: 16), color: .white)
                            .withRenderingMode(.alwaysTemplate)
                    )
                }

                // The cost already claims a line, so period and time share the next one.
                HStack(spacing: DesignSystem.Spaces.half) {
                    periodLabel
                    Text(verbatim: "·")
                        .font(.system(size: 11))
                    refreshLabel
                }
            } else {
                periodLabel
                refreshLabel
            }
        }
        .lineLimit(1)
        .foregroundStyle(WidgetEnergyPalette.secondaryText)
    }

    private var periodLabel: AnyView {
        periodControl(AnyView(WidgetEnergyPeriodLabel(title: periodTitle)))
    }

    private var refreshLabel: AnyView {
        refreshControl(AnyView(WidgetRefreshLabel(date: date, color: WidgetEnergyPalette.secondaryText)))
    }
}

@available(iOS 17, *)
#Preview {
    WidgetEnergyMediumContentView(
        stats: WidgetEnergySampleData.stats,
        costText: "−€0.49",
        periodTitle: "Today",
        date: WidgetEnergySampleData.dayStart,
        chartPoints: WidgetEnergySampleData.chartPoints,
        periodRange: WidgetEnergySampleData.dayRange
    )
    .frame(width: 338, height: 158)
}
#endif
