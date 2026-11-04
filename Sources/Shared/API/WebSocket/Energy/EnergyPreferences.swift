import Foundation
import HAKit

/// User's Energy Dashboard configuration, fetched via the `energy/get_prefs` websocket command.
/// Mirrors the frontend model in `home-assistant/frontend` `src/data/energy.ts`.
public struct EnergyPreferences: HADataDecodable, Codable, Equatable {
    public var energySources: [EnergySource]
    public var deviceConsumption: [EnergyDeviceConsumption]

    public init(energySources: [EnergySource], deviceConsumption: [EnergyDeviceConsumption]) {
        self.energySources = energySources
        self.deviceConsumption = deviceConsumption
    }

    public init(data: HAData) throws {
        self.energySources = data.decode("energy_sources", fallback: [])
        self.deviceConsumption = data.decode("device_consumption", fallback: [])
    }
}

/// A single configured energy source. The concrete meaning of each stat id depends on `type`
/// (grid/solar/battery/gas/water). All identifiers are optional because a dashboard may only
/// configure a subset (e.g. grid import without export or cost).
public struct EnergySource: HADataDecodable, Codable, Equatable {
    public var type: String
    /// Import meter for grid; production meter for solar; discharge for battery; consumption for gas/water.
    public var statEnergyFrom: String?
    /// Return-to-grid meter; charge meter for battery.
    public var statEnergyTo: String?
    public var statCost: String?
    public var statCompensation: String?
    public var entityEnergyPrice: String?
    public var numberEnergyPrice: Double?
    /// Instantaneous power/flow-rate entity used for the live "Now" readings.
    public var statRate: String?
    public var powerConfig: EnergyPowerConfig?
    public var name: String?

    public init(data: HAData) throws {
        self.type = try data.decode("type")
        self.statEnergyFrom = data.decode("stat_energy_from", fallback: nil)
        self.statEnergyTo = data.decode("stat_energy_to", fallback: nil)
        self.statCost = data.decode("stat_cost", fallback: nil)
        self.statCompensation = data.decode("stat_compensation", fallback: nil)
        self.entityEnergyPrice = data.decode("entity_energy_price", fallback: nil)
        self.numberEnergyPrice = data.decode("number_energy_price", fallback: nil)
        self.statRate = data.decode("stat_rate", fallback: nil)
        self.name = data.decode("name", fallback: nil)

        if case let .dictionary(dictionary) = data, let rawPowerConfig = dictionary["power_config"] {
            self.powerConfig = try? EnergyPowerConfig(data: .init(value: rawPowerConfig))
        } else {
            self.powerConfig = nil
        }
    }

    public init(
        type: String,
        statEnergyFrom: String? = nil,
        statEnergyTo: String? = nil,
        statCost: String? = nil,
        statCompensation: String? = nil,
        entityEnergyPrice: String? = nil,
        numberEnergyPrice: Double? = nil,
        statRate: String? = nil,
        powerConfig: EnergyPowerConfig? = nil,
        name: String? = nil
    ) {
        self.type = type
        self.statEnergyFrom = statEnergyFrom
        self.statEnergyTo = statEnergyTo
        self.statCost = statCost
        self.statCompensation = statCompensation
        self.entityEnergyPrice = entityEnergyPrice
        self.numberEnergyPrice = numberEnergyPrice
        self.statRate = statRate
        self.powerConfig = powerConfig
        self.name = name
    }
}

/// Optional live-power entities for grid/battery sources that separate import/export power.
public struct EnergyPowerConfig: HADataDecodable, Codable, Equatable {
    public var statRate: String?
    public var statRateFrom: String?
    public var statRateTo: String?
    public var inverted: Bool

    public init(data: HAData) throws {
        self.statRate = data.decode("stat_rate", fallback: nil)
        self.statRateFrom = data.decode("stat_rate_from", fallback: nil)
        self.statRateTo = data.decode("stat_rate_to", fallback: nil)
        self.inverted = data.decode("stat_rate_inverted", fallback: false)
    }
}

/// A monitored device in the "Individual devices" section of the dashboard.
public struct EnergyDeviceConsumption: HADataDecodable, Codable, Equatable {
    public var statConsumption: String
    public var statRate: String?
    public var name: String?

    public init(data: HAData) throws {
        self.statConsumption = try data.decode("stat_consumption")
        self.statRate = data.decode("stat_rate", fallback: nil)
        self.name = data.decode("name", fallback: nil)
    }
}

public extension HATypedRequest {
    /// Fetches the Energy Dashboard preferences.
    static func energyGetPrefs() -> HATypedRequest<EnergyPreferences> {
        .init(request: .init(type: .webSocket("energy/get_prefs")))
    }
}
