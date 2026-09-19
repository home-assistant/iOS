import Foundation
import HADesignSystem

/// Turns a `recorder/statistics_during_period` response into the figures and buckets an energy
/// summary is drawn from.
///
/// It exists because there are now two of those summaries — the iPhone's Energy widget and the
/// Apple Watch's energy complication — and they have to agree. Both plot the same stacked bars in
/// the same colours, so the step that decides what a bucket contains belongs in one place on both
/// platforms rather than once per target.
///
/// Everything here is pure: hand it statistic ids and a response, get totals and chart points back.
public enum EnergyStatisticsSummary {
    /// The statistic ids feeding each series, as the energy dashboard's preferences resolve them.
    ///
    /// A battery reads the opposite way round to a grid source: its `stat_energy_from` is what it
    /// gave back and its `stat_energy_to` what it took, where a grid source's "from" is the import.
    public struct Series: Sendable {
        public let gridImport: [String]
        public let gridExport: [String]
        public let solar: [String]
        public let batteryDischarge: [String]
        public let batteryCharge: [String]

        public init(
            gridImport: [String] = [],
            gridExport: [String] = [],
            solar: [String] = [],
            batteryDischarge: [String] = [],
            batteryCharge: [String] = []
        ) {
            self.gridImport = gridImport
            self.gridExport = gridExport
            self.solar = solar
            self.batteryDischarge = batteryDischarge
            self.batteryCharge = batteryCharge
        }

        /// The series the given energy sources describe, filtered by `type` the way the dashboard
        /// groups them. Gas and cost are deliberately absent: neither is a bar on this chart.
        public init(sources: [EnergySource]) {
            self.init(
                gridImport: sources.filter { $0.type == "grid" }.compactMap(\.statEnergyFrom),
                gridExport: sources.filter { $0.type == "grid" }.compactMap(\.statEnergyTo),
                solar: sources.filter { $0.type == "solar" }.compactMap(\.statEnergyFrom),
                batteryDischarge: sources.filter { $0.type == "battery" }.compactMap(\.statEnergyFrom),
                batteryCharge: sources.filter { $0.type == "battery" }.compactMap(\.statEnergyTo)
            )
        }

        public var all: [String] {
            Array(Set(gridImport + gridExport + solar + batteryDischarge + batteryCharge))
        }
    }

    /// Sum of the period's change across every statistic feeding one series — a home can have
    /// several meters per direction, and the dashboard reports their combined flow. Nil when the
    /// response carries none of them, which is how "not configured" stays distinct from "zero".
    public static func total(of ids: [String], in stats: EnergyStatistics) -> Double? {
        let present = ids.filter { stats.byStatId[$0] != nil }
        guard !present.isEmpty else { return nil }
        return present.reduce(0) { $0 + (stats.totalChange(for: $1) ?? 0) }
    }

    /// What the period cost overall: the metered imports' bill less what the exports earned back,
    /// the same netting the energy dashboard's totals table does. Compensation statistics count
    /// upward like any other, so summing them in would grow the bill with every kWh returned instead
    /// of shrinking it. Nil when the dashboard tracks no money at all; a home that earns more than it
    /// spends legitimately comes back negative.
    public static func netCost(cost: [String], compensation: [String], in stats: EnergyStatistics) -> Double? {
        let spent = total(of: cost, in: stats)
        let earned = total(of: compensation, in: stats)
        guard spent != nil || earned != nil else { return nil }
        return (spent ?? 0) - (earned ?? 0)
    }

    /// Builds the chart series per statistics bucket. All of them are clamped to ≥ 0 — they are
    /// magnitudes, and the chart is what decides which side of the axis each one is drawn on.
    public static func chartPoints(for series: Series, in stats: EnergyStatistics) -> [WidgetEnergyChartPoint] {
        let gridByStart = bucketTotals(ids: series.gridImport, in: stats)
        let returnedByStart = bucketTotals(ids: series.gridExport, in: stats)
        let solarByStart = bucketTotals(ids: series.solar, in: stats)
        let chargedByStart = bucketTotals(ids: series.batteryCharge, in: stats)
        let dischargedByStart = bucketTotals(ids: series.batteryDischarge, in: stats)
        let dates = Set(gridByStart.keys)
            .union(solarByStart.keys)
            .union(returnedByStart.keys)
            .union(chargedByStart.keys)
            .union(dischargedByStart.keys)
            .sorted()
        return dates.map { date in
            WidgetEnergyChartPoint(
                date: date,
                grid: max(gridByStart[date] ?? 0, 0),
                solar: max(solarByStart[date] ?? 0, 0),
                gridReturned: max(returnedByStart[date] ?? 0, 0),
                batteryCharged: max(chargedByStart[date] ?? 0, 0),
                batteryDischarged: max(dischargedByStart[date] ?? 0, 0)
            )
        }
    }

    /// Sums the given statistics' change per bucket start, merging the ids that feed one series.
    private static func bucketTotals(ids: [String], in stats: EnergyStatistics) -> [Date: Double] {
        var totals: [Date: Double] = [:]
        for id in ids {
            for bucket in stats.byStatId[id] ?? [] {
                totals[bucket.start, default: 0] += (bucket.change ?? 0)
            }
        }
        return totals
    }
}
