import Foundation

/// A representative day of energy statistics, shared by the widget gallery placeholder, the SwiftUI
/// previews and the snapshot tests so they all draw the same shape the real chart does.
///
/// The three series are derived from one another the way a real home's are: the house draws from the
/// grid whatever solar can't cover, and returns whatever solar it can't use. Keeping them consistent
/// matters because the chart splits generation into the part used at home and the part exported —
/// sample data that ignored the relationship would render a stack no home could produce.
@available(iOS 17, *)
enum WidgetEnergyChartSample {
    /// Hourly buckets covering the 24 hours from `dayStart`.
    static func day(startingAt dayStart: Date) -> [WidgetEnergyEntry.ChartPoint] {
        (0 ..< 24).map { hour in
            let h = Double(hour)
            // Household demand peaks in the morning and again in the evening; solar peaks midday.
            let load = 0.25 + 0.8 * exp(-pow(h - 7, 2) / 4) + 1.0 * exp(-pow(h - 20, 2) / 6)
            let solar = h >= 6 && h <= 18 ? 1.6 * sin((h - 6) / 12 * .pi) : 0
            return WidgetEnergyEntry.ChartPoint(
                date: dayStart.addingTimeInterval(h * 3600),
                grid: max(load - solar, 0),
                solar: solar,
                gridReturned: max(solar - load, 0)
            )
        }
    }

    /// The period totals the sample day adds up to, so a placeholder card's headline figures agree
    /// with the chart drawn underneath them.
    static func totals(of points: [WidgetEnergyEntry.ChartPoint])
        -> (gridConsumed: Double, gridReturned: Double, solarGenerated: Double) {
        (
            gridConsumed: points.reduce(0) { $0 + $1.grid },
            gridReturned: points.reduce(0) { $0 + $1.gridReturned },
            solarGenerated: points.reduce(0) { $0 + $1.solar }
        )
    }
}
