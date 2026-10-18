#if !os(watchOS)
import Foundation

/// One bucket of the energy chart, in the terms the chart paints: what came in, what was generated,
/// what the battery gave back or took, and what went back out.
public struct WidgetEnergyChartPoint: Identifiable, Equatable {
    public var id: Date { date }
    public let date: Date
    /// Energy consumed from the grid this bucket (kWh, ≥ 0).
    public let grid: Double
    /// Solar generated this bucket (kWh, ≥ 0).
    public let solar: Double
    /// Energy returned to the grid this bucket (kWh, ≥ 0).
    public let gridReturned: Double
    /// Energy that went into the battery this bucket (kWh, ≥ 0) — the source's `stat_energy_to`.
    public let batteryCharged: Double
    /// Energy the battery gave back this bucket (kWh, ≥ 0) — the source's `stat_energy_from`.
    public let batteryDischarged: Double

    /// Defaults everything but the two original series rather than relying on the memberwise
    /// initialiser, so the many call sites describing a home without export or a battery keep
    /// reading as two series.
    public init(
        date: Date,
        grid: Double,
        solar: Double,
        gridReturned: Double = 0,
        batteryCharged: Double = 0,
        batteryDischarged: Double = 0
    ) {
        self.date = date
        self.grid = grid
        self.solar = solar
        self.gridReturned = gridReturned
        self.batteryCharged = batteryCharged
        self.batteryDischarged = batteryDischarged
    }

    /// How the bucket's flows split between what the home used and what left the property, in the
    /// order the energy dashboard applies them. Ported from `computeConsumptionSingle` in the
    /// frontend's `src/data/energy.ts`, priority for priority, so the widget's bars stack the same
    /// way the dashboard's do:
    ///
    ///     Solar → Battery, Solar → Grid, Battery → Grid, Grid → Battery,
    ///     Solar → Consumption, Battery → Consumption, Grid → Consumption
    ///
    /// The one wrinkle is the first step. Grid import beyond what the home consumed can only have
    /// gone into the battery, so that share is claimed before solar fills it — otherwise the import
    /// is stranded with nowhere to go and the arithmetic stops balancing.
    private var split: Split {
        var toGrid = max(gridReturned, 0)
        var toBattery = max(batteryCharged, 0)
        var solarLeft = max(solar, 0)
        var fromGrid = max(grid, 0)
        var fromBattery = max(batteryDischarged, 0)

        // Everything the home used this bucket: what came in, less what went back out.
        let usedTotal = fromGrid + solarLeft + fromBattery - toGrid - toBattery
        var usedRemaining = max(usedTotal, 0)

        // Grid import the home didn't consume must be charging the battery. Claimed before solar
        // fills it, or that import would have nowhere to go.
        let excessGridIn = max(0, min(toBattery, fromGrid - usedRemaining))
        var gridToBattery = excessGridIn
        toBattery -= excessGridIn
        fromGrid -= excessGridIn

        // Solar → Battery, with whatever charge is still unaccounted for.
        let solarToBattery = min(solarLeft, toBattery)
        toBattery -= solarToBattery
        solarLeft -= solarToBattery

        // Solar → Grid.
        let solarToGrid = min(solarLeft, toGrid)
        toGrid -= solarToGrid
        solarLeft -= solarToGrid

        // Battery → Grid.
        let batteryToGrid = min(fromBattery, toGrid)
        fromBattery -= batteryToGrid

        // Grid → Battery, for any charge solar couldn't cover.
        let gridToBatterySecond = min(fromGrid, toBattery)
        gridToBattery += gridToBatterySecond
        fromGrid -= gridToBatterySecond

        // What's left of each source, in priority order, is what the home itself ran on.
        let usedSolar = min(usedRemaining, solarLeft)
        usedRemaining -= usedSolar
        let usedBattery = min(fromBattery, usedRemaining)
        usedRemaining -= usedBattery
        let usedGrid = min(usedRemaining, fromGrid)

        return Split(
            usedSolar: usedSolar,
            usedGrid: usedGrid,
            usedBattery: usedBattery,
            gridToBattery: gridToBattery,
            solarToBattery: solarToBattery,
            batteryToGrid: batteryToGrid,
            solarToGrid: solarToGrid
        )
    }

    /// The allocation of a bucket's flows, kept together so ``split`` is worked out once per read
    /// rather than once per series.
    struct Split: Equatable {
        let usedSolar: Double
        let usedGrid: Double
        let usedBattery: Double
        let gridToBattery: Double
        let solarToBattery: Double
        let batteryToGrid: Double
        let solarToGrid: Double
    }

    /// The share of this bucket's generation the home used itself. The chart paints this at the
    /// bottom of the consumption bar and draws the exported remainder below the axis, so plotting
    /// raw generation would count everything that was exported — or stored — twice.
    public var solarUsed: Double { split.usedSolar }

    /// The share of this bucket's grid import the home used itself. Below the raw import whenever
    /// some of it left again or went into the battery — energy that only passed through was never
    /// demand, and counting it would push the bar above what the home actually consumed.
    public var gridUsed: Double { split.usedGrid }

    /// The share of this bucket's discharge the home used itself, rather than sending to the grid.
    public var batteryUsed: Double { split.usedBattery }
}
#endif
