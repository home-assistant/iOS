import Foundation

public struct WidgetStateColorRule: Codable, Equatable, Hashable {
    public let comparison: WidgetStateColorRuleComparison
    public let threshold: Double
    public let color: String
    public let target: WidgetStateColorRuleTarget

    public init(
        comparison: WidgetStateColorRuleComparison,
        threshold: Double,
        color: String,
        target: WidgetStateColorRuleTarget
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
        target: WidgetStateColorRuleTarget,
        value: Double
    ) -> Self? {
        rules.first { $0.target == target && $0.matches(value) }
    }
}
