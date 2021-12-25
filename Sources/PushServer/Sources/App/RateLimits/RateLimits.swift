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
    func expirationDate(for identifier: String) async -> Date
    func rateLimit(for identifier: String) async throws -> RateLimitsValues
    func increment(kind: RateLimitsIncrementKind, for identifier: String) async throws -> RateLimitsValues
}

struct StartOfDayStorageKey: StorageKey {
    typealias Value = Date
}

class RateLimitsImpl: RateLimits {
    let cache: Cache
    init(cache: Cache) {
        self.cache = cache
        self.lock = .init()
    }

    private var lock: Lock
    private var expirationDate: Date?

    static func key(for identifier: String) -> String {
        "rateLimits:\(identifier)"
    }

    private var currentExpirationValue: CacheExpirationTime {
        lock.lock()

        let now = Date()
        let expiration: Date

        if let existing = expirationDate, existing > now {
            expiration = existing
        } else {
            let tomorrow = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
            expiration = tomorrow
            expirationDate = tomorrow
        }

        lock.unlock()

        return .seconds(Int(expiration.timeIntervalSince(now)))
    }

    func expirationDate(for identifier: String) async -> Date {
        if let expirationDate = expirationDate {
            return expirationDate
        } else {
            return Date(timeIntervalSinceNow: TimeInterval(currentExpirationValue.seconds))
        }
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
        try await cache.set(Self.key(for: identifier), to: updated, expiresIn: currentExpirationValue)
        return updated
    }
}
