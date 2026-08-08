import Foundation

public struct WidgetStateColorRule: Codable, Equatable, Hashable {
    public enum Comparison: String, Codable, CaseIterable {
        case lessThan
        case greaterThan
    }

    public enum Target: String, CaseIterable, Codable {
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

    public let comparison: Comparison
    public let threshold: Double
    public let color: String
    public let target: Target

    public init(
        comparison: Comparison,
        threshold: Double,
        color: String,
        target: Target
    ) {
        self.comparison = comparison
        self.threshold = threshold
        self.color = color
        self.target = target
    }

    public func matches(_ value: Double) -> Bool {
        switch comparison {
        case .lessThan:
            value < threshold
        case .greaterThan:
            value > threshold
        }
    }

    public static func matchingRule(
        in rules: [Self],
        target: Target,
        value: Double
    ) -> Self? {
        rules.first { $0.target == target && $0.matches(value) }
    }
}
