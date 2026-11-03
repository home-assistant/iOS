import Foundation
import HAKit
@testable import Shared
import Testing

/// Decoding of the energy dashboard's WebSocket payloads and the requests that fetch them.
struct EnergyPayloadDecodingTests {
    @Test func preferencesDecodeSourcesDevicesAndPowerConfig() throws {
        let prefs = try EnergyPreferences(data: .dictionary([
            "energy_sources": [
                [
                    "type": "grid",
                    "stat_energy_from": "sensor.import",
                    "stat_energy_to": "sensor.export",
                    "stat_cost": "sensor.cost",
                    "stat_compensation": "sensor.comp",
                    "entity_energy_price": "sensor.price",
                    "number_energy_price": 0.25,
                    "stat_rate": "sensor.power",
                    "name": "Grid",
                    "power_config": [
                        "stat_rate_from": "sensor.from",
                        "stat_rate_to": "sensor.to",
                        "stat_rate_inverted": true,
                    ],
                ],
                ["type": "solar", "stat_energy_from": "sensor.solar"],
            ],
            "device_consumption": [
                ["stat_consumption": "sensor.fridge", "stat_rate": "sensor.fridge_power", "name": "Fridge"],
            ],
        ]))
        #expect(prefs.energySources.count == 2)
        let grid = try #require(prefs.energySources.first)
        #expect(grid.type == "grid")
        #expect(grid.numberEnergyPrice == 0.25)
        #expect(grid.powerConfig?.inverted == true)
        #expect(grid.powerConfig?.statRateFrom == "sensor.from")
        #expect(prefs.energySources[1].powerConfig == nil)
        #expect(prefs.deviceConsumption.first?.name == "Fridge")

        let empty = try EnergyPreferences(data: .dictionary([:]))
        #expect(empty.energySources.isEmpty)
        #expect(empty.deviceConsumption.isEmpty)
        #expect(empty == EnergyPreferences(energySources: [], deviceConsumption: []))
        #expect(HATypedRequest<EnergyPreferences>.energyGetPrefs().request.type == .webSocket("energy/get_prefs"))
    }

    @Test func statisticsDecodeBucketsWithEveryTimestampShape() throws {
        let statistics = try EnergyStatistics(data: .dictionary([
            "sensor.import": [
                ["start": 1_700_000_000, "change": 1.5],
                ["start": 1_700_003_600_000 as Int64, "change": 2],
                ["start": "2026-01-01T00:00:00Z", "change": NSNull()],
                ["start": NSNull()],
            ],
            "ignored": "not a list",
        ]))
        let buckets = try #require(statistics.byStatId["sensor.import"])
        #expect(buckets.count == 4)
        #expect(buckets[0].start == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(buckets[1].start == Date(timeIntervalSince1970: 1_700_003_600))
        #expect(buckets[2].start == ISO8601DateFormatter().date(from: "2026-01-01T00:00:00Z"))
        #expect(buckets[3].start == Date(timeIntervalSince1970: 0))
        #expect(statistics.totalChange(for: "sensor.import") == 3.5)
        #expect(statistics.totalChange(for: "missing") == nil)
        #expect(statistics.byStatId["ignored"] == nil)
        #expect(throws: (any Error).self) { try EnergyStatistics(data: .array([])) }
    }

    @Test func metadataResolvesCommonUnits() throws {
        let metadata = try EnergyStatisticsMetadata(data: .array([
            .dictionary(["statistic_id": "sensor.gas", "unit_class": "volume", "display_unit_of_measurement": "m³"]),
            .dictionary(["statistic_id": "sensor.gas2", "unit_class": "volume", "display_unit_of_measurement": "m³"]),
            .dictionary(["statistic_id": "sensor.grid", "unit_class": "energy", "display_unit_of_measurement": "kWh"]),
            .dictionary(["no_id": true]),
        ]))
        #expect(metadata.byStatId.count == 3)
        #expect(metadata.commonUnitClass(of: ["sensor.gas", "sensor.gas2"]) == "volume")
        #expect(metadata.commonUnitClass(of: ["sensor.gas", "sensor.grid"]) == nil)
        #expect(metadata.commonDisplayUnit(of: ["sensor.gas"]) == "m³")
        #expect(metadata.commonDisplayUnit(of: ["missing"]) == nil)
        #expect(throws: (any Error).self) { try EnergyStatisticsMetadata(data: .dictionary([:])) }
    }

    @Test func requestsCarryTheirParameters() {
        let start = Date(timeIntervalSince1970: 0)
        let request = HATypedRequest<EnergyStatistics>.statisticsDuringPeriod(
            startTime: start,
            endTime: start.addingTimeInterval(3600),
            statisticIds: ["sensor.gas"],
            period: "day",
            volumeUnit: "m³"
        ).request
        #expect(request.type == .webSocket("recorder/statistics_during_period"))
        #expect(request.data["period"] as? String == "day")
        #expect((request.data["units"] as? [String: String])?["volume"] == "m³")
        #expect(request.data["start_time"] as? String == "1970-01-01T00:00:00Z")

        let metadata = HATypedRequest<EnergyStatisticsMetadata>.statisticsMetadata(statisticIds: ["a"]).request
        #expect(metadata.data["statistic_ids"] as? [String] == ["a"])
    }
}
