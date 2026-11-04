import Foundation

public struct PushProviderConfiguration: Codable, Equatable {
    public static let providerConfigurationKey = "ha_configurations"

    public let serverIdentifier: Identifier<Server>
    public let settingsKey: String

    public init(serverIdentifier: Identifier<Server>, settingsKey: String) {
        self.serverIdentifier = serverIdentifier
        self.settingsKey = settingsKey
    }

    public static func defaultSettingsKey(for server: Server) -> String {
        "LocalPush:\(server.identifier.rawValue)"
    }

    public static func decode(from data: Data?) -> [PushProviderConfiguration]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([PushProviderConfiguration].self, from: data)
    }
}
