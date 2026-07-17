import Foundation

/// First-pass decode of every incoming frame: just enough to route it. The frame's raw data is
/// kept alongside so the routed destination (which knows the concrete type) decodes it fully.
struct ServerEnvelope: Decodable {
    var id: Int?
    var type: String
    var success: Bool?
    var error: ErrorPayload?
    var haVersion: String?
    var message: String?

    enum CodingKeys: String, CodingKey {
        case id, type, success, error, message
        case haVersion = "ha_version"
    }

    struct ErrorPayload: Decodable {
        var code: String
        var message: String

        enum CodingKeys: String, CodingKey {
            case code, message
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let string = try? container.decode(String.self, forKey: .code) {
                self.code = string
            } else if let int = try? container.decode(Int.self, forKey: .code) {
                self.code = String(int)
            } else {
                self.code = "unknown"
            }
            self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
        }
    }
}
