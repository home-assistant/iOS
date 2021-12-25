@testable import App

class FakeRateLimits: RateLimits {
    var rateLimits = [String: RateLimitsValues]()

    func rateLimit(for identifier: String) async throws -> RateLimitsValues {
        rateLimits[identifier, default: .init()]
    }

    func increment(kind: RateLimitsIncrementKind, for identifier: String) async throws -> RateLimitsValues {
        var value = rateLimits[identifier, default: .init()]
        value.apply(kind)
        rateLimits[identifier] = value
        return value
    }
}
