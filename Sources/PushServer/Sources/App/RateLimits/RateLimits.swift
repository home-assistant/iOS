import Redis
import Vapor

public enum RateLimitsIncrementKind {
    case attempts
    case successful
    case error
}

public struct RateLimitsValues: Codable {
    public static let dailyMaximum: Int = 1_000
    public var successful: Int
    public var errors: Int

    public var exceedsMaximum: Bool {
        (successful + errors) >= Self.dailyMaximum
    }

    init() {
        self.successful = 0
        self.errors = 0
    }
}

public protocol RateLimits {
    func rateLimit(for identifier: String) async throws -> RateLimitsValues
    func increment(kind: RateLimitsIncrementKind, for identifier: String) async throws -> RateLimitsValues
}

class RateLimitsImpl: RateLimits {
    let cache: Cache
    init(cache: Cache) {
        self.cache = cache
    }

    private static func key(for identifier: String) -> String {
        "rateLimits:\(identifier)"
    }

    func rateLimit(for identifier: String) async throws -> RateLimitsValues {
        if let existing: RateLimitsValues = try await cache.get(Self.key(for: identifier)) {
            return existing
        } else {
            return .init()
        }
    }

    func increment(kind: RateLimitsIncrementKind, for identifier: String) async throws -> RateLimitsValues {
        var updated = try await rateLimit(for: identifier)

        switch kind {
        case .attempts: break
        case .successful: updated.successful += 1
        case .error: updated.errors += 1
        }

        try await cache.set(Self.key(for: identifier), to: updated)
        return updated
    }
}
