import Foundation

/// What recent barometer readings say about the device being inside a pressurized aircraft.
enum CabinPressureEvidence: Equatable {
    /// No barometer, no Motion & Fitness access, or not enough readings yet.
    case insufficientData
    /// Readings look like ground air: nothing here suggests a flight.
    case inconclusive
    /// Pressure is moving at a rate, and for long enough, that only cabin pressurization sustains.
    case sustainedChange(kpaPerMinute: Double)
    /// Pressure sits at cabin cruise level and far below the device's own recent ground baseline.
    case lowPressure(kpa: Double, belowBaselineKpa: Double)

    var indicatesFlight: Bool {
        switch self {
        case .insufficientData, .inconclusive:
            false
        case .sustainedChange, .lowPressure:
            true
        }
    }
}
