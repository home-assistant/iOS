#if !os(watchOS)
import Foundation
import HAIconic
import SFSafeSymbols
import SwiftUI

/// A believable day of energy data for previews and the component gallery: demand peaking morning
/// and evening, generation peaking at midday.
public enum WidgetEnergySampleData {
    /// A fixed day — 14 November 2023 — so a preview drawn today looks the same as one drawn next
    /// week.
    public static let dayStart = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))

    public static var dayRange: (start: Date, end: Date) {
        (dayStart, dayStart.addingTimeInterval(24 * 3600))
    }

    /// Hourly buckets covering the 24 hours from ``dayStart``.
    public static let chartPoints: [WidgetEnergyChartPoint] = (0 ..< 24).map { hour in
        let h = Double(hour)
        let flows = flows(atHour: h)
        return WidgetEnergyChartPoint(
            date: dayStart.addingTimeInterval(h * 3600),
            grid: flows.grid,
            solar: flows.solar,
            gridReturned: flows.returned
        )
    }

    /// The same day for a home that also has a battery: it stores the midday surplus instead of
    /// exporting all of it, and gives it back over the evening peak.
    public static let batteryChartPoints: [WidgetEnergyChartPoint] = (0 ..< 24).map { hour in
        let h = Double(hour)
        let flows = flows(atHour: h)
        // Charge from the surplus while the sun is high, discharge into the evening peak.
        let charged = min(flows.returned, h >= 10 && h <= 15 ? 0.9 : 0)
        let discharged = h >= 18 && h <= 22 ? min(flows.grid, 0.7) : 0
        return WidgetEnergyChartPoint(
            date: dayStart.addingTimeInterval(h * 3600),
            // What the battery covered was never drawn from the grid, and what it stored never left.
            grid: max(flows.grid - discharged, 0),
            solar: flows.solar,
            gridReturned: max(flows.returned - charged, 0),
            batteryCharged: charged,
            batteryDischarged: discharged
        )
    }

    /// One hour of the sample day: household demand peaks in the morning and again in the evening,
    /// generation peaks at midday, and the two are reconciled against the grid.
    private static func flows(atHour h: Double) -> (grid: Double, solar: Double, returned: Double) {
        let load = 0.25 + 0.8 * exp(-pow(h - 7, 2) / 4) + 1.0 * exp(-pow(h - 20, 2) / 6)
        let solar = h >= 6 && h <= 18 ? 1.6 * sin((h - 6) / 12 * .pi) : 0
        return (max(load - solar, 0), solar, max(solar - load, 0))
    }

    /// The period totals the sample day adds up to, so a card's headline figures agree with the
    /// chart drawn underneath them.
    public static var totals: (gridConsumed: Double, gridReturned: Double, solarGenerated: Double) {
        (
            gridConsumed: chartPoints.reduce(0) { $0 + $1.grid },
            gridReturned: chartPoints.reduce(0) { $0 + $1.gridReturned },
            solarGenerated: chartPoints.reduce(0) { $0 + $1.solar }
        )
    }

    /// The grid and solar figures the sample day works out to, ready to draw, in the order the
    /// widget shows them.
    public static var stats: [WidgetEnergyStatModel] {
        let totals = totals
        let net = totals.gridConsumed - totals.gridReturned
        return [
            WidgetEnergyStatModel(
                id: "grid",
                icon: .transmissionTowerIcon,
                value: WidgetEnergyPalette.energy(net),
                unit: WidgetEnergyPalette.energyUnit,
                label: "Grid",
                direction: WidgetEnergyPalette.gridDirection(ofTotal: net),
                color: WidgetEnergyPalette.consumption,
                accessorySymbol: .boltFill
            ),
            WidgetEnergyStatModel(
                id: "solar",
                icon: .solarPowerIcon,
                value: WidgetEnergyPalette.energy(totals.solarGenerated),
                unit: WidgetEnergyPalette.energyUnit,
                label: "Solar",
                direction: WidgetEnergyPalette.direction(ofTotal: totals.solarGenerated),
                color: WidgetEnergyPalette.solar,
                accessorySymbol: .sunMaxFill
            ),
        ]
    }

    /// Every series a dashboard can put on the widget, for the layouts that have to survive a home
    /// with all four. Battery reads the way the dashboard's total does — discharge positive — and
    /// gas carries its own unit rather than kWh, because a gas meter usually measures volume.
    @available(iOS 17, *)
    public static var allSourceStats: [WidgetEnergyStatModel] {
        let batteryNet = batteryChartPoints.reduce(0) { $0 + $1.batteryDischarged - $1.batteryCharged }
        return stats + [
            WidgetEnergyStatModel(
                id: "battery",
                icon: .batteryHighIcon,
                value: WidgetEnergyPalette.energy(batteryNet),
                unit: WidgetEnergyPalette.energyUnit,
                label: "Battery",
                direction: WidgetEnergyPalette.direction(ofTotal: batteryNet),
                color: WidgetEnergyPalette.batteryOut,
                accessorySymbol: .battery100percent
            ),
            WidgetEnergyStatModel(
                id: "gas",
                icon: .fireIcon,
                value: WidgetEnergyPalette.quantity(4.8),
                unit: "m³",
                label: "Gas",
                direction: .down,
                color: WidgetEnergyPalette.gas,
                accessorySymbol: .flameFill
            ),
        ]
    }
}
#endif
