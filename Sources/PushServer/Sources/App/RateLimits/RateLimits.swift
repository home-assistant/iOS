import Redis
import Vapor

public enum RateLimitsIncrementKind {
    case attempts
    case successful
    case error
}

public struct RateLimitsValues: Codable {
    public static let dailyMaximum: Int = 1000
    public var successful: Int
    public var errors: Int

    public var exceedsMaximum: Bool {
        (successful + errors) >= Self.dailyMaximum
    }

    public init() {
        self.successful = 0
        self.errors = 0
    }

    public init(successful: Int, errors: Int) {
        self.successful = successful
        self.errors = errors
    }

    mutating func apply(_ increment: RateLimitsIncrementKind) {
        switch increment {
        case .attempts: break
        case .successful: successful += 1
        case .error: errors += 1
        }
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
        updated.apply(kind)
        try await cache.set(Self.key(for: identifier), to: updated)
        return updated
    }
}
