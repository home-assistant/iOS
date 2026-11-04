import Foundation

public extension Version {
    /// HA version at which the webhook secret key uses the full-length key (ConnectionInfo).
    /// Other version feature-flags remain in AppConstants (Shared); this one moved here because
    /// ConnectionInfo needs it and cannot import Shared.
    static let fullWebhookSecretKey: Version = .init(major: 2022, minor: 3)
}
