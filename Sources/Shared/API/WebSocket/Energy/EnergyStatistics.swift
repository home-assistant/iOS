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
        self.change = (raw["change"] as? NSNumber)?.doubleValue
    }

    public init(start: Date, change: Double?) {
        self.start = start
        self.change = change
    }

    /// Statistics timestamps may arrive as ISO strings or as numeric epochs (seconds or milliseconds
    /// depending on the core version), so normalise defensively.
    private static func date(from value: Any?) -> Date? {
        if let number = value as? NSNumber {
            let seconds = number.doubleValue
            // A seconds epoch stays below 1e12 until roughly the year 33000, so a larger value is milliseconds.
            return Date(timeIntervalSince1970: seconds > 1e12 ? seconds / 1000 : seconds)
        }
        if let string = value as? String {
            return ISO8601DateFormatter().date(from: string)
        }
        return nil
    }
}

/// Result of `recorder/get_statistics_metadata`, keyed by statistic id. Only the part the widget
/// needs: which quantity a statistic measures, and the unit it is normally displayed in.
///
/// Gas is the reason this exists. A gas source is metered either by volume or by energy content, and
/// which one it is only shows up here — the energy preferences don't say. The frontend resolves it
/// the same way in `getEnergyGasUnitClass` (`src/data/energy.ts`).
public struct EnergyStatisticsMetadata: HADataDecodable, Codable, Equatable {
    public var byStatId: [String: Entry]

    public struct Entry: Codable, Equatable {
        /// The quantity the statistic measures — `energy`, `volume`, `power`… Nil for statistics the
        /// recorder can't convert between units at all.
        public var unitClass: String?
        /// The unit the statistic is presented in, e.g. `m³` or `kWh`.
        public var displayUnit: String?

        public init(unitClass: String?, displayUnit: String?) {
            self.unitClass = unitClass
            self.displayUnit = displayUnit
        }
    }

    public init(byStatId: [String: Entry]) {
        self.byStatId = byStatId
    }

    public init(data: HAData) throws {
        guard case let .array(items) = data else {
            throw HADataError.missingKey("root")
        }

        var result: [String: Entry] = [:]
        for item in items {
            guard case let .dictionary(dictionary) = item,
                  let statId = dictionary["statistic_id"] as? String else { continue }
            result[statId] = Entry(
                unitClass: dictionary["unit_class"] as? String,
                displayUnit: dictionary["display_unit_of_measurement"] as? String
            )
        }
        self.byStatId = result
    }

    /// The unit class shared by the given statistics, or nil when they disagree or none is known.
    /// Mixed classes have no single answer, so the caller is left to fall back rather than being
    /// handed whichever id happened to sort first.
    public func commonUnitClass(of statIds: [String]) -> String? {
        let classes = Set(statIds.compactMap { byStatId[$0]?.unitClass })
        return classes.count == 1 ? classes.first : nil
    }

    /// The display unit shared by the given statistics, or nil when they disagree or none is known.
    public func commonDisplayUnit(of statIds: [String]) -> String? {
        let units = Set(statIds.compactMap { byStatId[$0]?.displayUnit })
        return units.count == 1 ? units.first : nil
    }
}

public extension HATypedRequest {
    /// Fetches statistics for the given ids over a period. Requests the `change` type in kWh, matching
    /// how the energy dashboard computes daily totals.
    ///
    /// `volumeUnit` converts the volume-class statistics in the same request — gas metered by volume,
    /// which has no kWh reading to give. Energy-class statistics are unaffected by it, so one request
    /// still covers a dashboard that mixes the two.
    static func statisticsDuringPeriod(
        startTime: Date,
        endTime: Date,
        statisticIds: [String],
        period: String = "hour",
        volumeUnit: String? = nil
    ) -> HATypedRequest<EnergyStatistics> {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        var units = ["energy": "kWh"]
        if let volumeUnit {
            units["volume"] = volumeUnit
        }
        return .init(request: .init(
            type: .webSocket("recorder/statistics_during_period"),
            data: [
                "start_time": formatter.string(from: startTime),
                "end_time": formatter.string(from: endTime),
                "statistic_ids": statisticIds,
                "period": period,
                "types": ["change"],
                "units": units,
            ]
        ))
    }

    /// Fetches the recorder's metadata for the given statistics — notably a gas statistic's unit
    /// class, which decides whether it is read in m³ or in kWh.
    static func statisticsMetadata(statisticIds: [String]) -> HATypedRequest<EnergyStatisticsMetadata> {
        .init(request: .init(
            type: .webSocket("recorder/get_statistics_metadata"),
            data: ["statistic_ids": statisticIds]
        ))
    }
}
