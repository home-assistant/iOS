#if !os(watchOS)
import Foundation

/// One bucket of the energy chart, in the terms the chart paints: what came in, what was generated,
/// and what went back out.
public struct WidgetEnergyChartPoint: Identifiable, Equatable {
    public var id: Date { date }
    public let date: Date
    /// Energy consumed from the grid this bucket (kWh, ≥ 0).
    public let grid: Double
    /// Solar generated this bucket (kWh, ≥ 0).
    public let solar: Double
    /// Energy returned to the grid this bucket (kWh, ≥ 0).
    public let gridReturned: Double

    /// Defaults `gridReturned` rather than relying on the memberwise initialiser, so the many
    /// call sites describing a home without export keep reading as two series.
    public init(date: Date, grid: Double, solar: Double, gridReturned: Double = 0) {
        self.date = date
        self.grid = grid
        self.solar = solar
        self.gridReturned = gridReturned
    }

    /// How the bucket's flows split between what the home used and what left the property,
    /// following the order the energy dashboard applies (`computeConsumptionData` in the
    /// frontend's `src/data/energy.ts`): generation covers the export first, then the home's own
    /// demand, and the grid covers whatever demand is left.
    ///
    /// Batteries are deliberately absent from the order. The widget only resolves grid and solar
    /// sources from the energy preferences, so there is no charge or discharge to place in it.
    private var split: (solar: Double, grid: Double) {
        // Everything the home used this bucket: what came in, less what went back out.
        let usedTotal = max(grid + solar - gridReturned, 0)
        let generationLeftAfterExport = max(solar - gridReturned, 0)
        let solarUsed = min(usedTotal, generationLeftAfterExport)
        return (solarUsed, min(usedTotal - solarUsed, grid))
    }

    /// The share of this bucket's generation the home used itself. The chart paints this over
    /// the consumption bar and draws the exported remainder below the axis, so plotting raw
    /// generation would count everything that was exported twice.
    public var solarUsed: Double { split.solar }

    /// The share of this bucket's grid import the home used itself. Below the raw import
    /// whenever some of it left again — energy that only passed through was never demand, and
    /// counting it would push the bar above what the home actually consumed.
    public var gridUsed: Double { split.grid }
}
#endif
