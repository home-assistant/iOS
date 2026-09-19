import Foundation

/// One headline figure above the complication's chart — already formatted, because the watch app
/// that reads the statistics is also the only place that knows the user's locale-aware formatting.
///
/// Persisted as part of ``EnergyComplicationSnapshot``, so the widget extension renders exactly what
/// the app worked out rather than re-deriving it from raw numbers it never fetched.
public struct EnergyComplicationStat: Identifiable, Codable, Equatable, Sendable {
    public let series: EnergyComplicationSeries
    public let value: String
    /// Unit symbol, or nil when the figure carries none. Gas brings its own (m³/ft³/kWh); everything
    /// else is kWh.
    public let unit: String?

    public var id: String { series.rawValue }

    public init(series: EnergyComplicationSeries, value: String, unit: String?) {
        self.series = series
        self.value = value
        self.unit = unit
    }

    /// Formats a bare quantity the way the Energy widget does: locale-aware, and at most one
    /// fraction digit until the figure reaches three digits, where the decimal is only noise.
    ///
    /// Kept here rather than in the watch app so the formatting the face shows is covered by the
    /// package's own tests — the app target that calls it has no test host of its own.
    public static func quantity(_ value: Double) -> String {
        abs(value).formatted(.number.precision(.fractionLength(abs(value) >= 100 ? 0 : 1)))
    }

    /// Unit symbol for energy, sourced from Foundation rather than hardcoded, matching the widget.
    public static let energyUnit = UnitEnergy.kilowattHours.symbol

    /// An energy figure in kWh.
    public static func energy(_ series: EnergyComplicationSeries, kWh: Double) -> Self {
        .init(series: series, value: quantity(kWh), unit: energyUnit)
    }
}
