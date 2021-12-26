import SharedPush
import Vapor

public extension Application {
    var rateLimits: RateLimits {
        .init(application: self)
    }

    struct RateLimits {
        let application: Application

        struct RateLimitsKey: StorageKey {
            typealias Value = RateLimitsImpl
        }

        private var rateLimits: RateLimitsImpl? {
            get {
                application.storage[RateLimitsKey.self]
            }
            nonmutating set {
                self.application.storage[RateLimitsKey.self] = newValue
            }
        }

        var cache: Cache? {
            get {
                rateLimits?.cache
            }
            nonmutating set {
                self.application.storage[RateLimitsKey.self] = newValue.flatMap { RateLimitsImpl(cache: $0) }
            }
        }
    }
}

extension Application.RateLimits: RateLimits {
    public func expirationDate(for identifier: String) async -> Date {
        if let rateLimits = rateLimits {
            return await rateLimits.expirationDate(for: identifier)
        } else {
            fatalError("rate limits not configured before use")
        }
    }

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
