import Foundation

/// A believable day of energy data for previews, the complication picker and the snapshot tests:
/// demand peaking morning and evening, generation peaking at midday.
///
/// Fixed to 14 November 2023 so a preview drawn today looks like one drawn next week, and so the
/// recorded snapshot references don't change with the calendar.
public enum EnergyComplicationSampleData {
    public static let dayStart = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))

    /// A home with solar and a grid connection: it uses what it generates and exports the surplus.
    public static let bars: [EnergyComplicationChartBar] = (0 ..< 24).map { hour in
        let flows = flows(atHour: Double(hour))
        return EnergyComplicationChartBar(
            date: dayStart.addingTimeInterval(Double(hour) * 3600),
            solarUsed: min(flows.load, flows.solar),
            gridUsed: max(flows.load - flows.solar, 0),
            gridReturned: max(flows.solar - flows.load, 0)
        )
    }

    /// The same day for a home that also has a battery: it stores the midday surplus instead of
    /// exporting all of it, and gives it back over the evening peak.
    public static let batteryBars: [EnergyComplicationChartBar] = (0 ..< 24).map { hour in
        let h = Double(hour)
        let flows = flows(atHour: h)
        let exported = max(flows.solar - flows.load, 0)
        let fromGrid = max(flows.load - flows.solar, 0)
        let charged = min(exported, h >= 10 && h <= 15 ? 0.9 : 0)
        let discharged = h >= 18 && h <= 22 ? min(fromGrid, 0.7) : 0
        return EnergyComplicationChartBar(
            date: dayStart.addingTimeInterval(h * 3600),
            solarUsed: min(flows.load, flows.solar),
            batteryUsed: discharged,
            // What the battery covered was never drawn from the grid.
            gridUsed: max(fromGrid - discharged, 0),
            batteryCharged: charged,
            // What the battery stored never left the property.
            gridReturned: max(exported - charged, 0)
        )
    }

    /// The grid and solar figures the sample day adds up to, so the numbers above the chart agree
    /// with the bars drawn under them.
    public static var stats: [EnergyComplicationStat] {
        let imported = bars.reduce(0) { $0 + $1.gridUsed }
        let returned = bars.reduce(0) { $0 + $1.gridReturned }
        let solar = bars.reduce(0) { $0 + $1.solarUsed + $1.gridReturned }
        return [
            .energy(.grid, kWh: imported - returned),
            .energy(.solar, kWh: solar),
        ]
    }

    /// Every series a dashboard can put on the complication, for the layout that has to survive a
    /// home with all of them.
    public static var allSourceStats: [EnergyComplicationStat] {
        let batteryNet = batteryBars.reduce(0) { $0 + $1.batteryUsed - $1.batteryCharged }
        return stats + [
            .energy(.batteryOut, kWh: batteryNet),
            .init(series: .gas, value: EnergyComplicationStat.quantity(4.8), unit: "m³"),
        ]
    }

    /// One hour of the sample day: household demand peaks in the morning and again in the evening,
    /// generation peaks at midday.
    private static func flows(atHour h: Double) -> (load: Double, solar: Double) {
        let load = 0.25 + 0.8 * exp(-pow(h - 7, 2) / 4) + 1.0 * exp(-pow(h - 20, 2) / 6)
        let solar = h >= 6 && h <= 18 ? 1.6 * sin((h - 6) / 12 * .pi) : 0
        return (load, solar)
    }
}
