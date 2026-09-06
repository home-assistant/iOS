import Foundation

/// Tracks the offset and drift between this device's monotonic clock and the server's, from the
/// four timestamps each `client/time` and `server/time` exchange produces.
///
/// It is a two-dimensional Kalman filter over `[offset, drift]`: a plain average of round trips
/// cannot separate a clock that is 5 ms behind from one that is running slow, and audio has to stay
/// within ±1 ms of where the filter predicts, over hours.
struct SendspinClockFilter {
    /// Samples needed before playback may start, alongside the covariance test below.
    private static let minimumSamples = 5
    /// The filter is trusted once its offset standard deviation is inside a millisecond.
    private static let convergedStandardDeviation: Double = 1_000
    /// Floor on measurement noise, so a suspiciously fast round trip cannot dominate the estimate.
    private static let minimumMeasurementNoise: Double = 2_500

    private var offset: Double = 0
    private var drift: Double = 0
    private var referenceTime: Double = 0
    private var covariance: (Double, Double, Double, Double) = (0, 0, 0, 0)
    private var sampleCount = 0

    private(set) var lastRoundTripMicroseconds: Int64 = 0

    var isConverged: Bool {
        sampleCount >= Self.minimumSamples && covariance.0.squareRoot() < Self.convergedStandardDeviation
    }

    var snapshot: SendspinClockSnapshot? {
        guard sampleCount > 0 else { return nil }
        return SendspinClockSnapshot(
            offsetMicroseconds: offset,
            driftPerMicrosecond: drift,
            referenceLocalMicroseconds: referenceTime
        )
    }

    /// Estimated standard deviation of the offset, in microseconds. Shown in diagnostics.
    var offsetStandardDeviation: Double {
        covariance.0.squareRoot()
    }

    mutating func reset() {
        offset = 0
        drift = 0
        referenceTime = 0
        covariance = (0, 0, 0, 0)
        sampleCount = 0
        lastRoundTripMicroseconds = 0
    }

    /// Feeds one completed round trip in. All four timestamps are microseconds; the first and last
    /// are local, the middle two are the server's.
    mutating func update(
        clientTransmitted: Int64,
        serverReceived: Int64,
        serverTransmitted: Int64,
        clientReceived: Int64
    ) {
        let roundTrip = (clientReceived - clientTransmitted) - (serverTransmitted - serverReceived)
        // A negative round trip means one of the two clocks moved under us; the sample is unusable.
        guard roundTrip >= 0 else { return }
        lastRoundTripMicroseconds = roundTrip

        let measurement = Double((serverReceived - clientTransmitted) + (serverTransmitted - clientReceived)) / 2
        let measurementTime = Double(clientTransmitted + clientReceived) / 2

        guard sampleCount > 0 else {
            offset = measurement
            drift = 0
            referenceTime = measurementTime
            // Start wide: one round trip says a lot about offset and nothing about drift.
            covariance = (1_000_000, 0, 0, 1e-6)
            sampleCount = 1
            return
        }

        let elapsed = measurementTime - referenceTime
        referenceTime = measurementTime
        offset += drift * elapsed

        // Predict. F = [[1, elapsed], [0, 1]], with a random walk on both states.
        let elapsedSeconds = max(elapsed / 1_000_000, 0)
        let offsetProcessNoise = 100 * elapsedSeconds
        let driftProcessNoise = 1e-18 * elapsedSeconds
        var (p00, p01, p10, p11) = covariance
        p00 = p00 + elapsed * (p01 + p10) + elapsed * elapsed * p11 + offsetProcessNoise
        p01 += elapsed * p11
        p10 += elapsed * p11
        p11 += driftProcessNoise

        // Update. H = [1, 0]; half the round trip bounds how asymmetric the path can be.
        let measurementNoise = max(pow(Double(roundTrip) / 2, 2), Self.minimumMeasurementNoise)
        let innovationCovariance = p00 + measurementNoise
        let gainOffset = p00 / innovationCovariance
        let gainDrift = p10 / innovationCovariance
        let innovation = measurement - offset
        offset += gainOffset * innovation
        drift += gainDrift * innovation

        covariance = (
            (1 - gainOffset) * p00,
            (1 - gainOffset) * p01,
            p10 - gainDrift * p00,
            p11 - gainDrift * p01
        )
        sampleCount += 1
    }
}
