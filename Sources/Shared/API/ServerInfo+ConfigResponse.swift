import Foundation

extension ServerInfo {
    /// Applies what the server reports about itself in `get_config`.
    ///
    /// Values the response leaves out keep what is already stored: a Home Assistant too old to
    /// report its instance ID would otherwise drop the one a previous version of it supplied, and
    /// with it the server's identity.
    mutating func apply(_ config: ConfigResponse) {
        connection.cloudhookURL = config.CloudhookURL
        connection.set(address: config.RemoteUIURL, for: .remoteUI)
        remoteName = config.LocationName ?? ServerInfo.defaultName
        hassDeviceId = config.hassDeviceId
        instanceID = config.instanceID ?? instanceID

        if let reportedVersion = try? Version(hassVersion: config.Version) {
            version = reportedVersion
        }
    }
}
