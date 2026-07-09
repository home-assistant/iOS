import Foundation
import HAKit

public struct EnergyPreferences: HADataDecodable, Codable, Equatable, Sendable {
    public let energySources: [EnergySource]

    public init(data: HAData) throws {
        self.energySources = (try? data.decode("energy_sources")) ?? []
    }

    public init(energySources: [EnergySource]) {
        self.energySources = energySources
    }

    public var hasGridSource: Bool {
        energySources.contains { $0.type == "grid" && !($0.statEnergyFrom ?? "").isEmpty }
    }
}

public struct EnergySource: HADataDecodable, Codable, Equatable, Sendable {
    public let type: String
    public let statEnergyFrom: String?
    public let statEnergyTo: String?
    public let name: String?

    public init(data: HAData) throws {
        self.type = try data.decode("type")
        self.statEnergyFrom = try? data.decode("stat_energy_from")
        self.statEnergyTo = try? data.decode("stat_energy_to")
        self.name = try? data.decode("name")
    }

    public init(type: String, statEnergyFrom: String? = nil, statEnergyTo: String? = nil, name: String? = nil) {
        self.type = type
        self.statEnergyFrom = statEnergyFrom
        self.statEnergyTo = statEnergyTo
        self.name = name
    }
}
