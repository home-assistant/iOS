import Foundation
import Shared
import WidgetKit

@available(iOS 17, *)
struct WidgetEnergyEntry: TimelineEntry {
    var date = Date()
    var period: WidgetEnergyPeriod = .today
    var source: WidgetEnergySource = .auto
    var serverName: String?

    /// Deep link opening the energy dashboard of the widget's server.
    var widgetURL: URL = AppConstants.deeplinkURL

    /// False when the selected server has no energy dashboard configured.
    var isConfigured = false

    /// True when the empty state is due to a failed load rather than a missing energy dashboard.
    var loadFailed = false

    /// True when the app has no active URL for the widget's server, so there is nowhere to load
    /// from. Distinct from `loadFailed`: no request was ever made, and the fix is in the server's
    /// URL configuration rather than a retry.
    var noConnection = false

    // Energy totals over the selected period, in kWh. Nil when the source isn't configured.
    var gridConsumed: Double?
    var gridReturned: Double?
    var solarGenerated: Double?
    var batteryCharged: Double?
    var batteryDischarged: Double?

    /// Gas consumed over the period, in ``gasUnit``. Unlike every other figure here this is not
    /// necessarily energy: a gas meter reports volume as often as it reports kWh.
    var gasConsumed: Double?
    /// The unit ``gasConsumed`` is expressed in — `m³`, `ft³` or `kWh`, as the recorder reports it.
    var gasUnit: String?

    // Monetary cost over the period, in `currencyCode`. Nil when no cost is tracked. Covers every
    // metered source the dashboard puts a price on — electricity and gas — the way its totals row
    // does, rather than electricity alone.
    var cost: Double?
    var currencyCode: String?

    // Instantaneous power in watts, used by the small family. Grid is net (>0 consuming, <0
    // returning); battery likewise (>0 discharging, <0 charging). Gas has no equivalent: its live
    // reading is a flow rate in m³/h, which is not a power and doesn't belong beside these.
    var livePowerGrid: Double?
    var livePowerSolar: Double?
    var livePowerBattery: Double?

    /// Per-bucket energy for the chart, in kWh: what came from the grid, what solar generated, what
    /// the battery took and gave back, and what went back to the grid. All of them are magnitudes;
    /// the chart decides which side of the axis each one is drawn on.
    var chartPoints: [ChartPoint] = []

    struct ChartPoint: Identifiable, Equatable {
        var id: Date { date }
        let date: Date
        /// Energy consumed from the grid this bucket (kWh, ≥ 0).
        let grid: Double
        /// Solar generated this bucket (kWh, ≥ 0).
        let solar: Double
        /// Energy returned to the grid this bucket (kWh, ≥ 0).
        let gridReturned: Double
        /// Energy that went into the battery this bucket (kWh, ≥ 0).
        let batteryCharged: Double
        /// Energy the battery gave back this bucket (kWh, ≥ 0).
        let batteryDischarged: Double

        /// Defaults everything but the two original series rather than relying on the memberwise
        /// initialiser, so the many call sites describing a home without export or a battery keep
        /// reading as two series.
        init(
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

        /// The share of this bucket's generation the home used itself. The chart paints this at the
        /// bottom of the consumption bar and draws the exported remainder below the axis, so
        /// plotting raw generation would count everything that was exported twice.
        ///
        /// Worked out by the design system's chart point, which is what actually renders, so there
        /// is one implementation of the split rather than two that can drift apart.
        var solarUsed: Double { designSystemModel.solarUsed }

        /// The share of this bucket's grid import the home used itself. Below the raw import
        /// whenever some of it left again — energy that only passed through was never demand, and
        /// counting it would push the bar above what the home actually consumed.
        var gridUsed: Double { designSystemModel.gridUsed }

        /// The share of this bucket's discharge the home used itself, rather than selling on.
        var batteryUsed: Double { designSystemModel.batteryUsed }
    }

    /// Whether the server reported anything for the period. Live power is deliberately excluded: it
    /// describes right now, not the window, so it can't stand in for missing statistics.
    var hasStatistics: Bool {
        gridConsumed != nil || gridReturned != nil || solarGenerated != nil
            || batteryCharged != nil || batteryDischarged != nil || gasConsumed != nil
            || !chartPoints.isEmpty
    }

    /// Net grid energy over the period (consumed − returned), oriented like the energy dashboard's
    /// "Electricity total": positive means the home drew more than it sent back.
    var gridNet: Double? {
        guard gridConsumed != nil || gridReturned != nil else { return nil }
        return (gridConsumed ?? 0) - (gridReturned ?? 0)
    }

    /// Net battery energy over the period (discharged − charged), oriented like the energy
    /// dashboard's "Battery total": positive means the battery gave the home more than it took.
    /// The opposite sign convention to ``gridNet`` — and the same one the dashboard uses, because a
    /// battery is read as a source of supply where the grid is read as a bill.
    var batteryNet: Double? {
        guard batteryCharged != nil || batteryDischarged != nil else { return nil }
        return (batteryDischarged ?? 0) - (batteryCharged ?? 0)
    }
}

@available(iOS 17.0, *)
extension WidgetEnergyEntry.ChartPoint {
    /// The drawing half of the bucket, for the design system's energy chart.
    var designSystemModel: WidgetEnergyChartPoint {
        .init(
            date: date,
            grid: grid,
            solar: solar,
            gridReturned: gridReturned,
            batteryCharged: batteryCharged,
            batteryDischarged: batteryDischarged
        )
    }
}
