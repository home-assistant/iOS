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
        // Household demand peaks in the morning and again in the evening; solar peaks midday.
        let load = 0.25 + 0.8 * exp(-pow(h - 7, 2) / 4) + 1.0 * exp(-pow(h - 20, 2) / 6)
        let solar = h >= 6 && h <= 18 ? 1.6 * sin((h - 6) / 12 * .pi) : 0
        return WidgetEnergyChartPoint(
            date: dayStart.addingTimeInterval(h * 3600),
            grid: max(load - solar, 0),
            solar: solar,
            gridReturned: max(solar - load, 0)
        )
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

    /// The solar and grid figures the sample day works out to, ready to draw.
    public static var stats: [WidgetEnergyStatModel] {
        let totals = totals
        let net = totals.gridConsumed - totals.gridReturned
        return [
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
            WidgetEnergyStatModel(
                id: "grid",
                icon: .transmissionTowerIcon,
                value: WidgetEnergyPalette.energy(net),
                unit: WidgetEnergyPalette.energyUnit,
                label: "Electricity total",
                direction: WidgetEnergyPalette.gridDirection(ofTotal: net),
                color: WidgetEnergyPalette.consumption,
                accessorySymbol: .boltFill
            ),
        ]
    }
}
#endif
