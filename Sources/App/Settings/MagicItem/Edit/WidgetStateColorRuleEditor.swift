import Shared
import SwiftUI

struct WidgetStateColorRuleEditor: View {
    @Environment(\.dismiss) private var dismiss

    private static let thresholdFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    @State private var comparison: WidgetStateColorRuleComparison
    @State private var threshold: String
    @State private var color: Color
    @State private var target: WidgetStateColorRuleTarget

    let onSave: (WidgetStateColorRule) -> Void

    private var parsedThreshold: Double? {
        let trimmedThreshold = threshold.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.thresholdFormatter.number(from: trimmedThreshold)?.doubleValue
    }

    init(rule: WidgetStateColorRule?, onSave: @escaping (WidgetStateColorRule) -> Void) {
        let rule = rule ?? .init(
            comparison: .lessThan,
            threshold: .zero,
            color: UIColor.systemRed.hexString(),
            target: .state
        )
        self._comparison = .init(initialValue: rule.comparison)
        self._threshold = .init(
            initialValue: Self.thresholdFormatter.string(from: NSNumber(value: rule.threshold)) ?? rule.threshold
                .description
        )
        self._color = .init(initialValue: Color(hex: rule.color))
        self._target = .init(initialValue: rule.target)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section {
                Picker(L10n.MagicItem.StateColors.Comparison.title, selection: $comparison) {
                    Text(L10n.MagicItem.StateColors.Comparison.lessThan)
                        .tag(WidgetStateColorRuleComparison.lessThan)
                    Text(L10n.MagicItem.StateColors.Comparison.greaterThan)
                        .tag(WidgetStateColorRuleComparison.greaterThan)
                }

                HStack {
                    Text(L10n.MagicItem.StateColors.Threshold.title)
                    Spacer()
                    TextField("0", text: $threshold)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }
            } header: {
                Text(L10n.MagicItem.StateColors.Condition.title)
            } footer: {
                Text(L10n.MagicItem.StateColors.Condition.footer)
            }

            Section {
                Picker(L10n.MagicItem.StateColors.Target.title, selection: $target) {
                    Text(L10n.MagicItem.StateColors.Target.State.title)
                        .tag(WidgetStateColorRuleTarget.state)
                    Text(L10n.MagicItem.StateColors.Target.Icon.title)
                        .tag(WidgetStateColorRuleTarget.icon)
                    Text(L10n.MagicItem.StateColors.Target.Background.title)
                        .tag(WidgetStateColorRuleTarget.background)
                }

                ColorPicker(L10n.MagicItem.StateColors.Color.title, selection: $color, supportsOpacity: false)
            }
        }
        .navigationTitle(L10n.MagicItem.StateColors.Edit.title)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(L10n.cancelLabel) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.saveLabel) {
                    guard let threshold = parsedThreshold else {
                        return
                    }
                    onSave(.init(
                        comparison: comparison,
                        threshold: threshold,
                        color: color.hex() ?? UIColor.systemRed.hexString(),
                        target: target
                    ))
                    dismiss()
                }
                .disabled(parsedThreshold == nil)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WidgetStateColorRuleEditor(rule: nil) { _ in
        }
    }
}
