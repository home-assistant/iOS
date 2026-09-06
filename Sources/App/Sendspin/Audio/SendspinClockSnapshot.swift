import Foundation

/// A frozen view of the clock filter, cheap enough to hand to the audio render thread.
///
/// The model is `serverTime = localTime + offset + drift * (localTime - reference)`, so mapping a
/// server timestamp back to local time is one Newton step — drift is small enough that a second
/// pass changes nothing at the horizons audio is scheduled over.
struct SendspinClockSnapshot: Equatable {
    let offsetMicroseconds: Double
    let driftPerMicrosecond: Double
    let referenceLocalMicroseconds: Double

    func serverTime(forLocal local: Double) -> Double {
        local + offsetMicroseconds + driftPerMicrosecond * (local - referenceLocalMicroseconds)
    }

    func localTime(forServer server: Double) -> Double {
        let approximate = server - offsetMicroseconds
        return server - (serverTime(forLocal: approximate) - approximate)
    }
}
