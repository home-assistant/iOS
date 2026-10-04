import Foundation
import HAKit
@testable import Shared
import Testing

struct EnergyStatisticsTests {
    // MARK: - Statistics

    @Test func decodesBucketsPerStatistic() throws {
        let buckets: [[String: Any]] = [
            ["start": 1_700_000_000, "change": 1.5],
            ["start": 1_700_003_600_000, "change": 2],
            ["start": "2026-01-02T10:00:00Z", "change": NSNull()],
            ["change": 0.5],
        ]
        let raw: [String: Any] = [
            "sensor.grid": buckets,
            "sensor.not_buckets": "ignored",
        ]

        let statistics = try EnergyStatistics(data: HAData(value: raw))

        let decoded = try #require(statistics.byStatId["sensor.grid"])
        #expect(statistics.byStatId["sensor.not_buckets"] == nil)
        #expect(decoded.count == 4)
        // Seconds epoch.
        #expect(decoded[0].start == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(decoded[0].change == 1.5)
        // Milliseconds epoch.
        #expect(decoded[1].start == Date(timeIntervalSince1970: 1_700_003_600))
        #expect(decoded[1].change == 2)
        // ISO 8601 string.
        #expect(decoded[2].start == Date(timeIntervalSince1970: 1_767_348_000))
        #expect(decoded[2].change == nil)
        // Missing start.
        #expect(decoded[3].start == Date(timeIntervalSince1970: 0))
    }

    @Test func decodingRequiresADictionary() {
        #expect(throws: HADataError.self) {
            try EnergyStatistics(data: HAData(value: [1, 2, 3]))
        }
    }

    @Test func totalChangeSumsBucketsTreatingMissingAsZero() {
        let statistics = EnergyStatistics(byStatId: [
            "sensor.grid": [
                EnergyStatisticBucket(start: Date(timeIntervalSince1970: 0), change: 1.25),
                EnergyStatisticBucket(start: Date(timeIntervalSince1970: 3600), change: nil),
                EnergyStatisticBucket(start: Date(timeIntervalSince1970: 7200), change: 2.75),
            ],
            "sensor.empty": [],
        ])

        #expect(statistics.totalChange(for: "sensor.grid") == 4)
        #expect(statistics.totalChange(for: "sensor.empty") == 0)
        #expect(statistics.totalChange(for: "sensor.missing") == nil)
    }

    // MARK: - Metadata

    @Test func decodesMetadataEntries() throws {
        let raw: [[String: Any]] = [
            [
                "statistic_id": "sensor.gas",
                "unit_class": "volume",
                "display_unit_of_measurement": "m³",
            ],
            [
                "statistic_id": "sensor.grid",
                "unit_class": "energy",
                "display_unit_of_measurement": "kWh",
            ],
            ["unit_class": "energy"],
        ]

        let metadata = try EnergyStatisticsMetadata(data: HAData(value: raw))

        #expect(metadata.byStatId.count == 2)
        #expect(metadata.byStatId["sensor.gas"] == EnergyStatisticsMetadata.Entry(unitClass: "volume", displayUnit: "m³"))
        #expect(metadata.byStatId["sensor.grid"] == EnergyStatisticsMetadata.Entry(unitClass: "energy", displayUnit: "kWh"))
    }

    @Test func metadataDecodingRequiresAnArray() {
        #expect(throws: HADataError.self) {
            try EnergyStatisticsMetadata(data: HAData(value: ["statistic_id": "sensor.gas"]))
        }
    }

    @Test func commonUnitClassAndDisplayUnit() {
        let metadata = EnergyStatisticsMetadata(byStatId: [
            "sensor.gas_a": .init(unitClass: "volume", displayUnit: "m³"),
            "sensor.gas_b": .init(unitClass: "volume", displayUnit: "ft³"),
            "sensor.grid": .init(unitClass: "energy", displayUnit: "kWh"),
            "sensor.unknown": .init(unitClass: nil, displayUnit: nil),
        ])

        #expect(metadata.commonUnitClass(of: ["sensor.gas_a", "sensor.gas_b"]) == "volume")
        #expect(metadata.commonUnitClass(of: ["sensor.gas_a", "sensor.grid"]) == nil)
        #expect(metadata.commonUnitClass(of: ["sensor.unknown", "sensor.missing"]) == nil)
        #expect(metadata.commonUnitClass(of: ["sensor.grid", "sensor.unknown"]) == "energy")

        #expect(metadata.commonDisplayUnit(of: ["sensor.gas_a"]) == "m³")
        #expect(metadata.commonDisplayUnit(of: ["sensor.gas_a", "sensor.gas_b"]) == nil)
        #expect(metadata.commonDisplayUnit(of: []) == nil)
    }

    // MARK: - Requests

    @Test func statisticsDuringPeriodRequest() throws {
        let request = HATypedRequest<EnergyStatistics>.statisticsDuringPeriod(
            startTime: Date(timeIntervalSince1970: 1_767_225_600),
            endTime: Date(timeIntervalSince1970: 1_767_312_000),
            statisticIds: ["sensor.grid", "sensor.solar"]
        ).request

        #expect(request.type == .webSocket("recorder/statistics_during_period"))
        #expect(request.data["start_time"] as? String == "2026-01-01T00:00:00Z")
        #expect(request.data["end_time"] as? String == "2026-01-02T00:00:00Z")
        #expect(request.data["statistic_ids"] as? [String] == ["sensor.grid", "sensor.solar"])
        #expect(request.data["period"] as? String == "hour")
        #expect(request.data["types"] as? [String] == ["change"])
        #expect(request.data["units"] as? [String: String] == ["energy": "kWh"])
    }

    @Test func statisticsDuringPeriodRequestWithVolumeUnit() {
        let request = HATypedRequest<EnergyStatistics>.statisticsDuringPeriod(
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 86400),
            statisticIds: ["sensor.gas"],
            period: "day",
            volumeUnit: "m³"
        ).request

        #expect(request.data["period"] as? String == "day")
        #expect(request.data["units"] as? [String: String] == ["energy": "kWh", "volume": "m³"])
    }

    @Test func statisticsMetadataRequest() {
        let request = HATypedRequest<EnergyStatisticsMetadata>.statisticsMetadata(
            statisticIds: ["sensor.gas"]
        ).request

        #expect(request.type == .webSocket("recorder/get_statistics_metadata"))
        #expect(request.data["statistic_ids"] as? [String] == ["sensor.gas"])
    }
}
