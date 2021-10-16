import Foundation

class AuthRequestMessage: WebSocketMessage {
    public var AccessToken: String = ""

    private enum CodingKeys: String, CodingKey {
        case AccessToken = "access_token"
    }

    init(accessToken: String) {
        super.init("auth")
        self.ID = nil
        self.AccessToken = accessToken
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let superdecoder = try values.superDecoder()
        try super.init(from: superdecoder)

        self.AccessToken = try values.decode(String.self, forKey: .AccessToken)
    }

    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(AccessToken, forKey: .AccessToken)

        try super.encode(to: encoder)
    }
}
