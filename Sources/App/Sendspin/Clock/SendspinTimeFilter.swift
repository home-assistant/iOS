import Foundation

/// The two-dimensional Kalman filter over clock offset and drift that the specification requires
/// players to use, ported from the Sendspin `time-filter` reference implementation.
struct SendspinTimeFilter {
    private enum Constants {
        /// A residual beyond this multiple of the measurement's error triggers adaptive forgetting.
        static let adaptiveForgettingCutoff = 3.0
        /// Half the round trip overestimates the real measurement noise.
        static let maxErrorScale = 0.5
        /// Drift is only applied once `drift² > threshold² * driftCovariance`.
        static let driftSignificanceThresholdSquared = 4.0
        static let warmupCount = 100
    }

    private let processVariance: Double
    private let driftProcessVariance: Double
    private let forgetVarianceFactor: Double

    private var lastUpdate: Int64 = 0
    private(set) var count = 0
    private(set) var offset: Double = 0
    private var drift: Double = 0
    private var offsetCovariance = Double.infinity
    private var offsetDriftCovariance: Double = 0
    private var driftCovariance: Double = 0

    private(set) var mapping = SendspinClockMapping()

    init(processStdDev: Double = 0, forgetFactor: Double = 2, driftProcessStdDev: Double = 1e-11) {
        self.processVariance = processStdDev * processStdDev
        self.driftProcessVariance = driftProcessStdDev * driftProcessStdDev
        self.forgetVarianceFactor = forgetFactor * forgetFactor
    }

    /// Whether the estimate is good enough to schedule audio, which gates reporting the player as
    /// available.
    var isSynchronized: Bool {
        count >= 2 && offsetCovariance.isFinite
    }

    /// Standard deviation of the offset estimate, in microseconds.
    var error: Int64 {
        guard offsetCovariance.isFinite else { return .max }
        return Int64(offsetCovariance.squareRoot().rounded())
    }

    /// Feeds one `client/time` / `server/time` exchange.
    mutating func update(sample: SendspinServerTime, receivedAt: Int64) {
        let measurement = (
            Double(sample.serverReceived - sample.clientTransmitted) +
                Double(sample.serverTransmitted - receivedAt)
        ) / 2
        let maxError = (
            Double(receivedAt - sample.clientTransmitted) -
                Double(sample.serverTransmitted - sample.serverReceived)
        ) / 2
        update(measurement: Int64(measurement.rounded()), maxError: Int64(maxError.rounded()), timeAdded: receivedAt)
    }

    mutating func update(measurement: Int64, maxError: Int64, timeAdded: Int64) {
        // A non-monotonic sample would make the prediction step run backwards.
        guard timeAdded > lastUpdate else { return }

        let dt = Double(timeAdded - lastUpdate)
        lastUpdate = timeAdded

        let updateStdDev = Double(maxError) * Constants.maxErrorScale
        let measurementVariance = updateStdDev * updateStdDev
        let measured = Double(measurement)

        if count <= 0 {
            count += 1
            offset = measured
            offsetCovariance = measurementVariance
            drift = 0
            mapping = SendspinClockMapping(lastUpdate: lastUpdate, offset: offset, drift: drift)
            return
        }

        if count == 1 {
            count += 1
            drift = (measured - offset) / dt
            offset = measured
            driftCovariance = (offsetCovariance + measurementVariance) / (dt * dt)
            offsetCovariance = measurementVariance
            mapping = SendspinClockMapping(lastUpdate: lastUpdate, offset: offset, drift: drift)
            return
        }

        // Prediction.
        let predictedOffset = offset + drift * dt
        var newDriftCovariance = driftCovariance + dt * driftProcessVariance
        var newOffsetDriftCovariance = offsetDriftCovariance + driftCovariance * dt
        var newOffsetCovariance = offsetCovariance
            + 2 * offsetDriftCovariance * dt
            + driftCovariance * dt * dt
            + dt * processVariance

        // Innovation and adaptive forgetting.
        let residual = measured - predictedOffset
        if count < Constants.warmupCount {
            count += 1
        } else if abs(residual) > Double(maxError) * Constants.adaptiveForgettingCutoff {
            newDriftCovariance *= forgetVarianceFactor
            newOffsetDriftCovariance *= forgetVarianceFactor
            newOffsetCovariance *= forgetVarianceFactor
        }

        // Update.
        let uncertainty = 1 / max(newOffsetCovariance + measurementVariance, 1e-9)
        let offsetGain = newOffsetCovariance * uncertainty
        let driftGain = newOffsetDriftCovariance * uncertainty

        offset = predictedOffset + offsetGain * residual
        drift += driftGain * residual

        driftCovariance = newDriftCovariance - driftGain * newOffsetDriftCovariance
        offsetDriftCovariance = newOffsetDriftCovariance - driftGain * newOffsetCovariance
        offsetCovariance = newOffsetCovariance - offsetGain * newOffsetCovariance

        mapping = SendspinClockMapping(
            lastUpdate: lastUpdate,
            offset: offset,
            drift: drift,
            useDrift: drift * drift > Constants.driftSignificanceThresholdSquared * driftCovariance
        )
    }

    /// How often to sample the clock: often while converging, rarely once the estimate is tight.
    var nextSampleInterval: TimeInterval {
        guard isSynchronized else { return 0.2 }
        switch error {
        case ..<1000: return 3
        case ..<2000: return 1
        case ..<5000: return 0.5
        default: return 0.2
        }
    }
}
