import Redis
import Vapor

public enum RateLimitsIncrementKind {
    case successful
    case error
}

public struct RateLimitsValues: Codable, Equatable {
    public static let dailyMaximum: Int = 1000
    public var successful: Int
    public var errors: Int

    // minimizing storage cost
    enum CodingKeys: String, CodingKey {
        case successful = "s"
        case errors = "e"
    }

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
    let nowProvider: () -> Date

    init(cache: Cache, nowProvider: @escaping () -> Date = Date.init) {
        self.cache = cache
        self.nowProvider = nowProvider
        self.lock = .init()
    }

    private var lock: Lock
    private var expirationDate: Date?

    static func key(for identifier: String) -> String {
        "r\(identifier)"
    }

    private var currentExpirationDate: Date {
        lock.lock()
        defer { lock.unlock() }

        let now = nowProvider()

        if let existing = expirationDate, existing > now {
            return existing
        } else {
            let tomorrow = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
            expirationDate = tomorrow
            return tomorrow
        }
    }

    private var currentExpirationValue: CacheExpirationTime {
        let now = nowProvider()
        let expiration = currentExpirationDate
        return .seconds(Int(expiration.timeIntervalSince(now)))
    }

    func expirationDate(for identifier: String) async -> Date {
        currentExpirationDate
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
