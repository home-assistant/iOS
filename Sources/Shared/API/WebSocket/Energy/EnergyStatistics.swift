import Foundation
import HAKit

/// Result of `recorder/statistics_during_period`: a dictionary keyed by statistic id, each holding
/// an ordered list of buckets. We only request the `change` type, so that's the value carried here.
public struct EnergyStatistics: HADataDecodable, Codable, Equatable {
    public var byStatId: [String: [EnergyStatisticBucket]]

    public init(byStatId: [String: [EnergyStatisticBucket]]) {
        self.byStatId = byStatId
    }

    public init(data: HAData) throws {
        guard case let .dictionary(dictionary) = data else {
            throw HADataError.missingKey("root")
        }

        var result: [String: [EnergyStatisticBucket]] = [:]
        for (statId, value) in dictionary {
            guard let rawBuckets = value as? [[String: Any]] else { continue }
            result[statId] = rawBuckets.map { EnergyStatisticBucket(raw: $0) }
        }
        self.byStatId = result
    }

    /// Sum of every bucket's `change` for the given statistic id, or nil when the id is absent.
    public func totalChange(for statId: String) -> Double? {
        guard let buckets = byStatId[statId] else { return nil }
        return buckets.reduce(0) { $0 + ($1.change ?? 0) }
    }
}

public struct EnergyStatisticBucket: Codable, Equatable {
    public var start: Date
    public var change: Double?

    init(raw: [String: Any]) {
        self.start = Self.date(from: raw["start"]) ?? Date(timeIntervalSince1970: 0)
        self.change = raw["change"] as? Double
    }

    public init(start: Date, change: Double?) {
        self.start = start
        self.change = change
    }

    /// Statistics timestamps may arrive as ISO strings or as numeric epochs (seconds or milliseconds
    /// depending on the core version), so normalise defensively.
    private static func date(from value: Any?) -> Date? {
        if let number = value as? Double {
            // Heuristic: values past ~year 2286 in seconds are actually milliseconds.
            return Date(timeIntervalSince1970: number > 1e12 ? number / 1000 : number)
        }
        if let string = value as? String {
            return ISO8601DateFormatter().date(from: string)
        }
        return nil
    }
}

public extension HATypedRequest {
    /// Fetches statistics for the given ids over a period. Requests the `change` type in kWh, matching
    /// how the energy dashboard computes daily totals.
    static func statisticsDuringPeriod(
        startTime: Date,
        endTime: Date,
        statisticIds: [String],
        period: String = "hour"
    ) -> HATypedRequest<EnergyStatistics> {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        return .init(request: .init(
            type: .webSocket("recorder/statistics_during_period"),
            data: [
                "start_time": formatter.string(from: startTime),
                "end_time": formatter.string(from: endTime),
                "statistic_ids": statisticIds,
                "period": period,
                "types": ["change"],
                "units": ["energy": "kWh"],
            ]
        ))
    }
}
