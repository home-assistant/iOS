import Shared
import SwiftUI

struct WidgetStateColorRuleEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var comparison: WidgetStateColorRule.Comparison
    @State private var threshold: String
    @State private var color: Color
    @State private var target: WidgetStateColorRule.Target

    let onSave: (WidgetStateColorRule) -> Void

    private var parsedThreshold: Double? {
        let trimmedThreshold = threshold.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let decimalThreshold = Decimal(string: trimmedThreshold, locale: .current) else {
            return nil
        }
        return NSDecimalNumber(decimal: decimalThreshold).doubleValue
    }

    init(rule: WidgetStateColorRule?, onSave: @escaping (WidgetStateColorRule) -> Void) {
        let rule = rule ?? .init(
            comparison: .lessThan,
            threshold: .zero,
            color: UIColor.systemRed.hexString(),
            target: .state
        )
        self._comparison = .init(initialValue: rule.comparison)
        self._threshold = .init(initialValue: rule.threshold.formatted())
        self._color = .init(initialValue: Color(hex: rule.color))
        self._target = .init(initialValue: rule.target)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section {
                Picker(L10n.MagicItem.StateColors.Comparison.title, selection: $comparison) {
                    Text(L10n.MagicItem.StateColors.Comparison.lessThan)
                        .tag(WidgetStateColorRule.Comparison.lessThan)
                    Text(L10n.MagicItem.StateColors.Comparison.greaterThan)
                        .tag(WidgetStateColorRule.Comparison.greaterThan)
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
                        .tag(WidgetStateColorRule.Target.state)
                    Text(L10n.MagicItem.StateColors.Target.Icon.title)
                        .tag(WidgetStateColorRule.Target.icon)
                    Text(L10n.MagicItem.StateColors.Target.Background.title)
                        .tag(WidgetStateColorRule.Target.background)
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
