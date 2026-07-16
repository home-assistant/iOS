import Foundation

/// Encodes the wire format `{"id": N, "type": command, ...data}` — the command's payload keys
/// are splatted at the top level of the message, per the Home Assistant websocket protocol.
struct ClientMessage: Encodable {
    var id: Int?
    var type: String
    var data: [String: HAAPIJSONValue]

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        if let id {
            try container.encode(id, forKey: AnyCodingKey("id"))
        }
        try container.encode(type, forKey: AnyCodingKey("type"))
        for (key, value) in data where key != "id" && key != "type" {
            try container.encode(value, forKey: AnyCodingKey(key))
        }
    }

    func encodedText() throws -> String {
        try String(decoding: JSONEncoder().encode(self), as: UTF8.self)
    }
}
