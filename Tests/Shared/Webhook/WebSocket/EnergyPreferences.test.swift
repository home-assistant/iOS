import Foundation
import HAKit
@testable import Shared
import Testing

struct EnergyPreferencesTests {
    @Test func decodesSourcesAndDevices() throws {
        let gridSource: [String: Any] = [
            "type": "grid",
            "stat_energy_from": "sensor.grid_import",
            "stat_energy_to": "sensor.grid_export",
            "stat_cost": "sensor.grid_cost",
            "stat_compensation": "sensor.grid_compensation",
            "entity_energy_price": "sensor.price",
            "number_energy_price": 0.25,
            "stat_rate": "sensor.grid_power",
            "name": "Grid",
            "power_config": [
                "stat_rate_from": "sensor.grid_power_in",
                "stat_rate_to": "sensor.grid_power_out",
                "stat_rate_inverted": true,
            ] as [String: Any],
        ]
        let solarSource: [String: Any] = ["type": "solar", "stat_energy_from": "sensor.solar"]
        let device: [String: Any] = [
            "stat_consumption": "sensor.fridge_energy",
            "stat_rate": "sensor.fridge_power",
            "name": "Fridge",
        ]
        let raw: [String: Any] = [
            "energy_sources": [gridSource, solarSource],
            "device_consumption": [device],
        ]

        let preferences = try EnergyPreferences(data: HAData(value: raw))

        #expect(preferences.energySources.count == 2)
        let grid = try #require(preferences.energySources.first { $0.type == "grid" })
        #expect(grid.statEnergyFrom == "sensor.grid_import")
        #expect(grid.statEnergyTo == "sensor.grid_export")
        #expect(grid.statCost == "sensor.grid_cost")
        #expect(grid.statCompensation == "sensor.grid_compensation")
        #expect(grid.entityEnergyPrice == "sensor.price")
        #expect(grid.numberEnergyPrice == 0.25)
        #expect(grid.statRate == "sensor.grid_power")
        #expect(grid.name == "Grid")
        let powerConfig = try #require(grid.powerConfig)
        #expect(powerConfig.statRate == nil)
        #expect(powerConfig.statRateFrom == "sensor.grid_power_in")
        #expect(powerConfig.statRateTo == "sensor.grid_power_out")
        #expect(powerConfig.inverted)

        let solar = try #require(preferences.energySources.first { $0.type == "solar" })
        #expect(solar.statEnergyFrom == "sensor.solar")
        #expect(solar.statEnergyTo == nil)
        #expect(solar.powerConfig == nil)

        #expect(preferences.deviceConsumption.count == 1)
        #expect(preferences.deviceConsumption.first?.statConsumption == "sensor.fridge_energy")
        #expect(preferences.deviceConsumption.first?.statRate == "sensor.fridge_power")
        #expect(preferences.deviceConsumption.first?.name == "Fridge")
    }

    @Test func missingSectionsAreEmpty() throws {
        let preferences = try EnergyPreferences(data: HAData(value: [String: Any]()))

        #expect(preferences.energySources.isEmpty)
        #expect(preferences.deviceConsumption.isEmpty)
    }

    @Test func sourceRequiresAType() {
        #expect(throws: HADataError.self) {
            try EnergySource(data: HAData(value: ["stat_energy_from": "sensor.grid"]))
        }
    }

    @Test func deviceRequiresAConsumptionStatistic() {
        #expect(throws: HADataError.self) {
            try EnergyDeviceConsumption(data: HAData(value: ["name": "Fridge"]))
        }
    }

    @Test func powerConfigDefaultsToNotInverted() throws {
        let config = try EnergyPowerConfig(data: HAData(value: ["stat_rate": "sensor.battery_power"]))

        #expect(config.statRate == "sensor.battery_power")
        #expect(config.statRateFrom == nil)
        #expect(config.statRateTo == nil)
        #expect(!config.inverted)
    }

    @Test func memberwiseSourceInitializer() {
        let source = EnergySource(type: "gas", statEnergyFrom: "sensor.gas", name: "Gas")

        #expect(source.type == "gas")
        #expect(source.statEnergyFrom == "sensor.gas")
        #expect(source.name == "Gas")
        #expect(source.statCost == nil)
        #expect(source.powerConfig == nil)
    }

    @Test func memberwisePreferencesInitializer() {
        let source = EnergySource(type: "grid")
        let preferences = EnergyPreferences(energySources: [source], deviceConsumption: [])

        #expect(preferences.energySources == [source])
        #expect(preferences.deviceConsumption.isEmpty)
    }

    @Test func requests() {
        #expect(HATypedRequest<EnergyPreferences>.energyGetPrefs().request.type == .webSocket("energy/get_prefs"))
        #expect(HATypedRequest<EnergyInfo>.energyInfo().request.type == .webSocket("energy/info"))
    }

    @Test func decodesEnergyInfo() throws {
        let raw: [String: Any] = [
            "cost_sensors": ["sensor.grid": "sensor.grid_cost"],
            "solar_forecast_domains": ["forecast_solar"],
        ]

        let info = try EnergyInfo(data: HAData(value: raw))

        #expect(info.costSensors == ["sensor.grid": "sensor.grid_cost"])
        #expect(info.solarForecastDomains == ["forecast_solar"])
    }
}
