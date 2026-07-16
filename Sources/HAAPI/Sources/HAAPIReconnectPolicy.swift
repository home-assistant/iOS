import Foundation

/// Exponential backoff with jitter for reconnect attempts. The attempt counter is reset by the
/// connection after every successful authentication, so a stable link always retries fast.
public struct HAAPIReconnectPolicy: Sendable {
    public var initialDelay: Duration
    public var maxDelay: Duration
    public var multiplier: Double
    public var jitterRange: ClosedRange<Double>

    public init(
        initialDelay: Duration = .seconds(1),
        maxDelay: Duration = .seconds(60),
        multiplier: Double = 2,
        jitterRange: ClosedRange<Double> = 0.8 ... 1.2
    ) {
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
        self.jitterRange = jitterRange
    }

    public static let exponentialBackoff = HAAPIReconnectPolicy()

    public func delay(forAttempt attempt: Int) -> Duration {
        guard attempt > 0 else { return .zero }
        let initial = Self.seconds(of: initialDelay)
        let cap = Self.seconds(of: maxDelay)
        let raw = min(initial * pow(multiplier, Double(attempt - 1)), cap)
        return .seconds(raw * Double.random(in: jitterRange))
    }

    private static func seconds(of duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}
