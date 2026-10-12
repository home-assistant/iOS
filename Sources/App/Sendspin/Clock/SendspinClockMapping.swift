import Foundation

/// A snapshot of the time filter's estimate, cheap to copy to the audio thread.
///
/// `serverTime = clientTime + offset + drift * (clientTime - lastUpdate)`, with drift only applied
/// once the filter considers it significant.
struct SendspinClockMapping: Equatable {
    var lastUpdate: Int64 = 0
    var offset: Double = 0
    var drift: Double = 0
    var useDrift = false

    private var effectiveDrift: Double { useDrift ? drift : 0 }

    func serverTime(fromClient clientTime: Int64) -> Int64 {
        let elapsed = Double(clientTime - lastUpdate)
        return clientTime + Int64((offset + effectiveDrift * elapsed).rounded())
    }

    /// The same mapping without rounding, which the renderer uses to place individual samples.
    func preciseServerTime(fromClient clientTime: Double) -> Double {
        clientTime + offset + effectiveDrift * (clientTime - Double(lastUpdate))
    }

    func clientTime(fromServer serverTime: Int64) -> Int64 {
        let drift = effectiveDrift
        return Int64(((Double(serverTime) - offset + drift * Double(lastUpdate)) / (1 + drift)).rounded())
    }
}
