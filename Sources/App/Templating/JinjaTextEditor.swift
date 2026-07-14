import Shared
import SwiftUI
import UIKit

/// The text view of the Jinja editor sheet: a `UITextView` (SwiftUI's `TextEditor` can't do live
/// syntax highlighting) with Jinja colors, cursor reporting for the entity suggestions below, and
/// an insertion channel for tapped suggestions. Smart punctuation is off — smart quotes silently
/// break Jinja.
struct JinjaTextEditor: UIViewRepresentable {
    @Binding var text: String
    /// The current cursor location (UTF-16), reported for the context-aware entity suggestions.
    @Binding var cursorLocation: Int
    /// Set by the suggestion pills / entity picker; the editor consumes it, inserts at the cursor,
    /// and clears it back to nil.
    @Binding var pendingInsertion: JinjaTemplateSuggestion?
    /// Focuses the editor (bringing up the keyboard) as soon as it appears.
    var autoFocus = false

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
        context.coordinator.applyHighlighting(text)
        if autoFocus {
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
            }
        }
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text {
            context.coordinator.applyHighlighting(text)
        }
        if let insertion = pendingInsertion {
            context.coordinator.insert(insertion)
            DispatchQueue.main.async {
                pendingInsertion = nil
            }
        }
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

        init(parent: JinjaTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            applyHighlighting(textView.text)
            reportCursor()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            reportCursor()
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

        func insert(_ suggestion: JinjaTemplateSuggestion) {
            guard let textView else { return }
            let nsText = textView.text as NSString
            let cursor = min(textView.selectedRange.location, nsText.length)
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
            reportCursor()
        }

        private func reportCursor() {
            guard let textView else { return }
            let location = textView.selectedRange.location
            DispatchQueue.main.async { [weak self] in
                self?.parent.cursorLocation = location
            }
        }
    }
}

#Preview {
    JinjaTextEditor(
        text: .constant("{{ states('sensor.solar_power') | round(1) }} kW"),
        cursorLocation: .constant(0),
        pendingInsertion: .constant(nil)
    )
    .padding()
}
