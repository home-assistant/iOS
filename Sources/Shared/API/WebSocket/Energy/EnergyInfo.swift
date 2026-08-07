import Foundation
import HAKit

/// Result of the `energy/info` websocket command. `costSensors` maps an energy statistic id to the
/// (possibly auto-generated) cost statistic id used to track its monetary cost.
public struct EnergyInfo: HADataDecodable, Codable, Equatable {
    public var costSensors: [String: String]
    public var solarForecastDomains: [String]

    public init(costSensors: [String: String], solarForecastDomains: [String]) {
        self.costSensors = costSensors
        self.solarForecastDomains = solarForecastDomains
    }

    public init(data: HAData) throws {
        self.costSensors = data.decode("cost_sensors", fallback: [:])
        self.solarForecastDomains = data.decode("solar_forecast_domains", fallback: [])
    }
}

public extension HATypedRequest {
    /// Fetches metadata about the energy configuration, notably the cost-sensor mapping.
    static func energyInfo() -> HATypedRequest<EnergyInfo> {
        .init(request: .init(type: .webSocket("energy/info")))
    }
}
