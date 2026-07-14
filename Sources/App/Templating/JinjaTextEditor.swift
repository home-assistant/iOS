import Shared
import SwiftUI
import UIKit

/// The text view of `JinjaTemplateView`: a `UITextView` (SwiftUI's `TextEditor` can't do either of
/// these) with live Jinja syntax highlighting and an autocomplete bar above the keyboard. Smart
/// punctuation is off — smart quotes silently break Jinja.
struct JinjaTextEditor: UIViewRepresentable {
    @Binding var text: String
    /// Entity ids of the selected server, offered by the autocomplete inside quoted strings.
    var entityIds: [String] = []

    static let font = UIFont.monospacedSystemFont(
        ofSize: UIFont.preferredFont(forTextStyle: .callout).pointSize,
        weight: .regular
    )

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.font = Self.font
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.keyboardType = .asciiCapable
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        context.coordinator.textView = textView
        textView.inputAccessoryView = context.coordinator.makeAccessoryView()
        context.coordinator.applyHighlighting(text)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text {
            context.coordinator.applyHighlighting(text)
        }
        context.coordinator.updateSuggestions()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(fitting.height, Self.font.lineHeight))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: JinjaTextEditor
        weak var textView: UITextView?
        /// Hosts the SwiftUI suggestion chips inside the keyboard's input accessory area.
        private let accessoryController = UIHostingController(
            rootView: JinjaAutocompleteBar(suggestions: [], onSelect: { _ in })
        )

        init(parent: JinjaTextEditor) {
            self.parent = parent
        }

        func makeAccessoryView() -> UIView {
            let view = accessoryController.view ?? UIView()
            view.frame = CGRect(x: 0, y: 0, width: 0, height: 44)
            view.backgroundColor = .clear
            return view
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            applyHighlighting(textView.text)
            updateSuggestions()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            updateSuggestions()
        }

        /// Re-applies syntax colors, keeping the cursor where it was.
        func applyHighlighting(_ text: String) {
            guard let textView else { return }
            let selection = textView.selectedRange
            textView.attributedText = JinjaSyntaxHighlighter.highlight(text, font: JinjaTextEditor.font)
            let length = (textView.text as NSString).length
            textView.selectedRange = NSRange(
                location: min(selection.location, length),
                length: min(selection.length, max(0, length - selection.location))
            )
        }

        func updateSuggestions() {
            guard let textView else { return }
            let provider = JinjaAutocompleteProvider(entityIds: parent.entityIds)
            let suggestions = provider.suggestions(
                text: textView.text,
                cursorLocation: textView.selectedRange.location
            )
            accessoryController.rootView = JinjaAutocompleteBar(suggestions: suggestions) { [weak self] in
                self?.insert($0)
            }
        }

        private func insert(_ suggestion: JinjaTemplateSuggestion) {
            guard let textView else { return }
            let nsText = textView.text as NSString
            let cursor = textView.selectedRange.location
            let replacingCount = min(suggestion.replacingCount, cursor)
            let replaceRange = NSRange(location: cursor - replacingCount, length: replacingCount)
            textView.text = nsText.replacingCharacters(in: replaceRange, with: suggestion.insertion)
            parent.text = textView.text
            applyHighlighting(textView.text)
            let insertionEnd = replaceRange.location + (suggestion.insertion as NSString).length
            textView.selectedRange = NSRange(
                location: max(0, insertionEnd - suggestion.cursorOffsetFromEnd),
                length: 0
            )
            updateSuggestions()
        }
    }
}

#Preview {
    JinjaTextEditor(
        text: .constant("{{ states('sensor.solar_power') | round(1) }} kW"),
        entityIds: ["sensor.solar_power"]
    )
    .padding()
}
