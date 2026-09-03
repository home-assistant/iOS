import Foundation

/// The watch's own `mobile_app` registration with one server: the webhook it reports through as a
/// device of its own, separate from the paired iPhone's registration that `ConnectionInfo` mirrors.
public struct WatchDeviceRegistration: Codable, Equatable {
    public var webhookID: String
    public var webhookSecret: String?
    public var cloudhookURL: URL?
    public var registeredAt: Date
    /// The enablement each sensor was last registered with, keyed by unique ID. Only
    /// `register_sensor` carries enablement to Home Assistant, so a sensor whose switch changed
    /// since — or that isn't in here at all — needs registering before its state is sent.
    public var registeredSensorEnablement: [String: Bool]

    public init(
        webhookID: String,
        webhookSecret: String?,
        cloudhookURL: URL?,
        registeredAt: Date,
        registeredSensorEnablement: [String: Bool] = [:]
    ) {
        self.webhookID = webhookID
        self.webhookSecret = webhookSecret
        self.cloudhookURL = cloudhookURL
        self.registeredAt = registeredAt
        self.registeredSensorEnablement = registeredSensorEnablement
    }

    public var webhookPath: String {
        "api/webhook/\(webhookID)"
    }

    /// The secretbox key for this registration, derived the same way as the phone's.
    public func webhookSecretBytes(version: Version) -> [UInt8]? {
        ConnectionInfo.webhookSecretBytes(secret: webhookSecret, version: version)
    }
}
