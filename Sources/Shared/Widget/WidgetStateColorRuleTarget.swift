import Foundation

public enum WidgetStateColorRuleTarget: String, CaseIterable, Codable {
    case state
    case icon
    case background

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "text", "state":
            // `text` was used before dynamic colors distinguished the title from the state.
            self = .state
        case "icon":
            self = .icon
        case "background":
            self = .background
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown widget state color target: \(value)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
