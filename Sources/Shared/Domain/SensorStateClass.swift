import Foundation

/// Mirrors Home Assistant's `SensorStateClass`, telling the backend how to treat a numeric
/// sensor's state so it can render statistics and history graphs instead of state-change bars.
public enum SensorStateClass: String, CaseIterable {
    /// The state represents a measurement in present time.
    case measurement
    /// The state represents a total that can increase and decrease.
    case total
    /// The state represents a monotonically increasing total which may periodically reset to 0.
    case totalIncreasing = "total_increasing"
}
