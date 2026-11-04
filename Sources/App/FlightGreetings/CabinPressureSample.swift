import Foundation

/// One barometer reading, as kept in `CabinPressureMonitor`'s rolling window and as the persisted
/// ground-pressure baseline.
struct CabinPressureSample: Equatable {
    let date: Date
    let pressureKpa: Double
}
