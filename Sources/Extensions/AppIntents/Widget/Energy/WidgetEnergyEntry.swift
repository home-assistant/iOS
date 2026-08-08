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

    // Energy totals over the selected period, in kWh. Nil when the source isn't configured.
    var gridConsumed: Double?
    var gridReturned: Double?
    var solarGenerated: Double?

    // Monetary cost over the period, in `currencyCode`. Nil when no cost is tracked.
    var cost: Double?
    var currencyCode: String?

    // Instantaneous power in watts, used by the small family. Grid is net (>0 consuming, <0 returning).
    var livePowerGrid: Double?
    var livePowerSolar: Double?

    /// Per-bucket energy for the chart: grid consumption and solar generation, stacked as positive
    /// bars above the axis, both in kWh.
    var chartPoints: [ChartPoint] = []

    struct ChartPoint: Identifiable, Equatable {
        var id: Date { date }
        let date: Date
        /// Energy consumed from the grid this bucket (kWh, ≥ 0).
        let grid: Double
        /// Solar generated this bucket (kWh, ≥ 0).
        let solar: Double
    }

    /// True when the entry carries at least one value a layout can render. Live power is only
    /// fetched for the small family, so it counts as data alongside the period totals.
    var hasData: Bool {
        let hasSolar = source.showsSolar && (livePowerSolar != nil || solarGenerated != nil)
        let hasGrid = source.showsGrid && (livePowerGrid != nil || gridNet != nil)
        return hasSolar || hasGrid || !chartPoints.isEmpty
    }

    /// Net grid energy over the period (returned − consumed). Positive means net export.
    var gridNet: Double? {
        guard gridConsumed != nil || gridReturned != nil else { return nil }
        return (gridReturned ?? 0) - (gridConsumed ?? 0)
    }
}
