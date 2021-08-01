import Foundation
import HAKit
import ObjectMapper

public struct MobileAppRegistrationResponse: HADataDecodable {
    public var CloudhookURL: URL?
    public var RemoteUIURL: URL?
    public var WebhookID: String
    public var WebhookSecret: String?

    public init(data: HAData) throws {
        self.CloudhookURL = try? data.decode("cloudhook_url", transform: URL.init(string:))
        self.RemoteUIURL = try? data.decode("remote_ui_url", transform: URL.init(string:))
        self.WebhookID = try data.decode("webhook_id")
        self.WebhookSecret = data.decode("secret", fallback: nil)
    }
}
