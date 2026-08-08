import Foundation
import Shared
import Testing

struct WidgetStateColorRuleTests {
    @Test("Less-than rules match values below their threshold")
    func lessThanRule() {
        let rule = WidgetStateColorRule(
            comparison: .lessThan,
            threshold: 0,
            color: "#FF0000",
            target: .state
        )

        #expect(rule.matches(-0.01))
        #expect(!rule.matches(0))
        #expect(!rule.matches(1))
    }

    @Test("Greater-than rules match values above their threshold")
    func greaterThanRule() {
        let rule = WidgetStateColorRule(
            comparison: .greaterThan,
            threshold: 100,
            color: "#00FF00",
            target: .background
        )

        #expect(!rule.matches(100))
        #expect(rule.matches(100.01))
    }

    @Test("The first matching rule for a target is selected")
    func firstMatchingRule() {
        let rules = [
            WidgetStateColorRule(comparison: .lessThan, threshold: 0, color: "red", target: .state),
            WidgetStateColorRule(comparison: .lessThan, threshold: 10, color: "yellow", target: .state),
            WidgetStateColorRule(comparison: .lessThan, threshold: 10, color: "blue", target: .icon),
        ]

        let matchingRule = WidgetStateColorRule.matchingRule(in: rules, target: .state, value: -5)

        #expect(matchingRule?.color == "red")
    }

    @Test("Older customizations decode without state color rules")
    func backwardCompatibleCustomizationDecoding() throws {
        let data = Data(#"{"requiresConfirmation":false}"#.utf8)

        let customization = try JSONDecoder().decode(MagicItem.Customization.self, from: data)

        #expect(customization.stateColorRules == nil)
    }

    @Test("Legacy text rules decode as state rules")
    func legacyTextRuleDecoding() throws {
        let data =
            Data(
                ##"{"requiresConfirmation":false,"stateColorRules":[{"comparison":"lessThan","threshold":0,"color":"#FF0000","target":"text"}]}"##
                    .utf8
            )

        let customization = try JSONDecoder().decode(MagicItem.Customization.self, from: data)

        #expect(customization.stateColorRules?.first?.target == .state)
    }
}
