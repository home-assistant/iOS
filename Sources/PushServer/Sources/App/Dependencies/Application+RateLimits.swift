import SharedPush
import Vapor

public extension Application {
    var rateLimits: RateLimitsInternal {
        .init(application: self)
    }

    struct RateLimitsInternal {
        let application: Application

        struct RateLimitsKey: StorageKey {
            typealias Value = RateLimits
        }

        public var rateLimits: RateLimits? {
            get {
                application.storage[RateLimitsKey.self]
            }
            nonmutating set {
                self.application.storage[RateLimitsKey.self] = newValue
            }
        }
    }
}

extension Application.RateLimitsInternal: RateLimits {
    public func rateLimit(for identifier: String) async throws -> RateLimitsValues {
        if let rateLimits = rateLimits {
            return try await rateLimits.rateLimit(for: identifier)
        } else {
            fatalError("rate limits not configured before use")
        }
    }

    public func increment(kind: RateLimitsIncrementKind, for identifier: String) async throws -> RateLimitsValues {
        if let rateLimits = rateLimits {
            return try await rateLimits.increment(kind: kind, for: identifier)
        } else {
            fatalError("rate limits not configured before use")
        }
    }
}
