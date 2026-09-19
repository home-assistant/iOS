import Foundation

/// One bucket of the complication's chart, already split into the shares the bars actually draw.
///
/// The split — how much of a bucket's generation, discharge and import the home itself used, as
/// opposed to what merely passed through on its way to the grid or the battery — is the energy
/// dashboard's own priority order, and the watch app resolves it with the same
/// `WidgetEnergyChartPoint` the phone's widget draws from. Persisting the result rather than the raw
/// meter readings keeps that one implementation, and leaves the widget extension with nothing to do
/// but paint rectangles.
public struct EnergyComplicationChartBar: Identifiable, Codable, Equatable, Sendable {
    public var id: Date { date }
    public let date: Date
    /// Generation the home consumed itself (kWh, ≥ 0).
    public let solarUsed: Double
    /// Discharge the home consumed itself (kWh, ≥ 0).
    public let batteryUsed: Double
    /// Grid import the home consumed itself (kWh, ≥ 0).
    public let gridUsed: Double
    /// Energy that went into the battery (kWh, ≥ 0). Drawn below the axis.
    public let batteryCharged: Double
    /// Energy returned to the grid (kWh, ≥ 0). Drawn below the axis.
    public let gridReturned: Double

    public init(
        date: Date,
        solarUsed: Double,
        batteryUsed: Double = 0,
        gridUsed: Double,
        batteryCharged: Double = 0,
        gridReturned: Double = 0
    ) {
        self.date = date
        self.solarUsed = solarUsed
        self.batteryUsed = batteryUsed
        self.gridUsed = gridUsed
        self.batteryCharged = batteryCharged
        self.gridReturned = gridReturned
    }

    /// Whether this bucket has anything at all to draw. A period whose buckets are all empty leaves
    /// the chart with nothing but its axis, which is worth knowing before drawing one.
    public var isEmpty: Bool {
        solarUsed <= 0 && batteryUsed <= 0 && gridUsed <= 0 && batteryCharged <= 0 && gridReturned <= 0
    }
}
