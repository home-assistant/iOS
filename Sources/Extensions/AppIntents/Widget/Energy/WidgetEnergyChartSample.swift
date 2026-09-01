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
            let flows = flows(atHour: h)
            return WidgetEnergyEntry.ChartPoint(
                date: dayStart.addingTimeInterval(h * 3600),
                grid: flows.grid,
                solar: flows.solar,
                gridReturned: flows.returned
            )
        }
    }

    /// The same day for a home that also has a battery: rather than exporting the whole midday
    /// surplus it stores part of it, and gives that back over the evening peak. Derived from the
    /// same curve for the same reason the three original series are — a battery that charged from
    /// energy the home never generated would draw a stack no home could produce.
    static func dayWithBattery(startingAt dayStart: Date) -> [WidgetEnergyEntry.ChartPoint] {
        (0 ..< 24).map { hour in
            let h = Double(hour)
            let flows = flows(atHour: h)
            let charged = min(flows.returned, h >= 10 && h <= 15 ? 0.9 : 0)
            let discharged = h >= 18 && h <= 22 ? min(flows.grid, 0.7) : 0
            return WidgetEnergyEntry.ChartPoint(
                date: dayStart.addingTimeInterval(h * 3600),
                // What the battery covered was never drawn from the grid, and what it stored never
                // left the property.
                grid: max(flows.grid - discharged, 0),
                solar: flows.solar,
                gridReturned: max(flows.returned - charged, 0),
                batteryCharged: charged,
                batteryDischarged: discharged
            )
        }
    }

    /// One hour of the sample day: household demand peaks in the morning and again in the evening,
    /// generation peaks at midday, and the two are reconciled against the grid.
    private static func flows(atHour h: Double) -> (grid: Double, solar: Double, returned: Double) {
        let load = 0.25 + 0.8 * exp(-pow(h - 7, 2) / 4) + 1.0 * exp(-pow(h - 20, 2) / 6)
        let solar = h >= 6 && h <= 18 ? 1.6 * sin((h - 6) / 12 * .pi) : 0
        return (max(load - solar, 0), solar, max(solar - load, 0))
    }

    /// The period totals the sample day adds up to, so a placeholder card's headline figures agree
    /// with the chart drawn underneath them.
    static func totals(of points: [WidgetEnergyEntry.ChartPoint])
        -> (
            gridConsumed: Double,
            gridReturned: Double,
            solarGenerated: Double,
            batteryCharged: Double,
            batteryDischarged: Double
        ) {
        (
            gridConsumed: points.reduce(0) { $0 + $1.grid },
            gridReturned: points.reduce(0) { $0 + $1.gridReturned },
            solarGenerated: points.reduce(0) { $0 + $1.solar },
            batteryCharged: points.reduce(0) { $0 + $1.batteryCharged },
            batteryDischarged: points.reduce(0) { $0 + $1.batteryDischarged }
        )
    }
}
