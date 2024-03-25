public struct PushProviderConfiguration: Codable {
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
}
