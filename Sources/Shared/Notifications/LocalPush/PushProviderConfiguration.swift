public struct PushProviderConfiguration: Codable {
    public static var providerConfigurationKey = "ha_configurations"

    public var serverIdentifier: Identifier<Server>
    public var settingsKey: String

    public init(serverIdentifier: Identifier<Server>, settingsKey: String) {
        self.serverIdentifier = serverIdentifier
        self.settingsKey = settingsKey
    }

    public static func defaultSettingsKey(for server: Server) -> String {
        "LocalPush:\(server.identifier.rawValue)"
    }
}
