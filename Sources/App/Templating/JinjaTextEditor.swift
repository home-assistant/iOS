import Shared
import SwiftUI

#if os(macOS)
/// The text view of the Jinja editor sheet on the Mac: an `NSTextView` (SwiftUI's `TextEditor` can't do
/// live syntax highlighting) with Jinja colors, cursor reporting for the entity suggestions below, and
/// an insertion channel for clicked suggestions. Smart punctuation is off — smart quotes silently
/// break Jinja.
struct JinjaTextEditor: NSViewRepresentable {
    @Binding var text: String
    /// The current cursor location (UTF-16), reported for the context-aware entity suggestions.
    @Binding var cursorLocation: Int
    /// Set by the suggestion pills / entity picker; the editor consumes it, inserts at the cursor,
    /// and clears it back to nil.
    @Binding var pendingInsertion: JinjaTemplateSuggestion?
    /// Known entity id ranges inside the current text, rendered as clickable inline pills.
    var entityReferences: [JinjaEntityReference] = []
    /// Called when the user clicks one of the inline entity pills.
    var onEntityTap: (JinjaEntityReference) -> Void = { _ in }
    /// Focuses the editor as soon as it appears.
    var autoFocus = false

    static let font = UIFont.monospacedSystemFont(
        ofSize: UIFont.preferredFont(forTextStyle: .callout).pointSize,
        weight: .regular
    )

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator

        // The text system is assembled by hand so the editor lays out with TextKit 1, which the pill
        // attachments and the hit testing on them are written against.
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)

        let textView = EditorTextView(frame: .zero, textContainer: textContainer)
        textView.minSize = .zero
        textView.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.drawsBackground = false
        textView.font = Self.font
        textView.isRichText = false
        textView.importsGraphics = false
        // Every change replaces the whole text with its highlighted copy, which the undo stack can't
        // follow.
        textView.allowsUndo = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.textContainerInset = .zero
        textView.delegate = coordinator
        textView.onMouseDown = { [weak coordinator] point in
            coordinator?.handleMouseDown(at: point) ?? false
        }
        textView.onAppearanceChange = { [weak coordinator] in
            coordinator?.reapplyHighlighting()
        }
        textView.focusesWhenShown = autoFocus

        // No scroller: the editor grows with its text, so there is normally nothing to scroll, and a
        // scroller that comes and goes would change the width the text wraps to.
        let scrollView = EditorScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView

        coordinator.textView = textView
        coordinator.textStorage = textStorage
        coordinator.applyHighlighting(text, entityReferences: entityReferences)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.appliedSourceText != text || context.coordinator
            .appliedEntityReferences != entityReferences {
            context.coordinator.applyHighlighting(text, entityReferences: entityReferences)
        }
        if let insertion = pendingInsertion {
            context.coordinator.scheduleInsertion(insertion)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        return CGSize(width: width, height: context.coordinator.fittingHeight(forWidth: width))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    /// Hands scrolling on to the enclosing form while the text fits, which is nearly always: the editor
    /// grows with its text and only scrolls itself when something holds it to a smaller height.
    final class EditorScrollView: NSScrollView {
        override func scrollWheel(with event: NSEvent) {
            if let documentView, documentView.frame.height > contentSize.height {
                super.scrollWheel(with: event)
            } else {
                nextResponder?.scrollWheel(with: event)
            }
        }
    }

    /// The text view, reporting what the editor needs to hear of: clicks, to catch the ones on an entity
    /// pill, and a change between light and dark.
    final class EditorTextView: NSTextView {
        /// Asked about every click before the text view acts on it. Returns true when the click landed
        /// on an entity pill and has been dealt with.
        var onMouseDown: ((CGPoint) -> Bool)?
        /// The pills are drawn as images, so they have to be drawn again when light and dark swap.
        var onAppearanceChange: (() -> Void)?
        var focusesWhenShown = false

        override func mouseDown(with event: NSEvent) {
            if onMouseDown?(convert(event.locationInWindow, from: nil)) == true {
                return
            }
            super.mouseDown(with: event)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard focusesWhenShown, window != nil else { return }
            focusesWhenShown = false
            // The window is still being put on screen when the view joins it, so wait for the next pass
            // of the run loop before taking the focus.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                window?.makeFirstResponder(self)
            }
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            onAppearanceChange?()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JinjaTextEditor
        weak var textView: EditorTextView?
        /// Held here because a text view whose text system was assembled by hand doesn't keep its
        /// storage alive.
        var textStorage: NSTextStorage?
        var appliedSourceText = ""
        var appliedEntityReferences: [JinjaEntityReference] = []
        private var displayEntityRanges: [(displayRange: NSRange, reference: JinjaEntityReference)] = []
        private var scheduledInsertion: JinjaTemplateSuggestion?

        init(parent: JinjaTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            // Text that is still being composed (a dead key, an input method) is left alone: swapping
            // it for its highlighted copy would end the composition.
            guard let textView, !textView.hasMarkedText() else { return }
            let sourceText = sourceText(from: textView.attributedString())
            parent.text = sourceText
            applyHighlighting(sourceText, entityReferences: parent.entityReferences)
            reportCursor()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            reportCursor()
        }

        /// Re-applies syntax colors, keeping the cursor where it was.
        func applyHighlighting(_ text: String, entityReferences: [JinjaEntityReference]) {
            guard let textView, let textStorage else { return }
            let selectedSourceLocation = sourceLocation(forDisplayLocation: textView.selectedRange().location)
            appliedSourceText = text
            appliedEntityReferences = entityReferences
            textStorage.setAttributedString(displayText(for: text, entityReferences: entityReferences))
            // What is typed next takes these until the following pass colors it.
            textView.typingAttributes = [
                .font: JinjaTextEditor.font,
                .foregroundColor: UIColor.secondaryLabel,
            ]
            textView.setSelectedRange(NSRange(
                location: min(displayLocation(forSourceLocation: selectedSourceLocation), textStorage.length),
                length: 0
            ))
        }

        func reapplyHighlighting() {
            applyHighlighting(appliedSourceText, entityReferences: appliedEntityReferences)
        }

        func scheduleInsertion(_ suggestion: JinjaTemplateSuggestion) {
            guard scheduledInsertion != suggestion else { return }
            scheduledInsertion = suggestion

            DispatchQueue.main.async { [weak self] in
                guard let self, scheduledInsertion == suggestion else { return }
                parent.pendingInsertion = nil
                insert(suggestion)
                scheduledInsertion = nil
            }
        }

        private func insert(_ suggestion: JinjaTemplateSuggestion) {
            guard let textView else { return }
            let nsText = parent.text as NSString
            let cursor = min(parent.cursorLocation, nsText.length)
            let replaceRange: NSRange
            if let replacementRange = suggestion.replacementRange,
               NSMaxRange(replacementRange) <= nsText.length {
                replaceRange = replacementRange
            } else {
                let replacingCount = min(suggestion.replacingCount, cursor)
                replaceRange = NSRange(location: cursor - replacingCount, length: replacingCount)
            }
            let nextText = nsText.replacingCharacters(in: replaceRange, with: suggestion.insertion)
            parent.text = nextText
            applyHighlighting(nextText, entityReferences: parent.entityReferences)
            let insertionEnd = replaceRange.location + (suggestion.insertion as NSString).length
            textView.setSelectedRange(NSRange(
                location: displayLocation(forSourceLocation: max(0, insertionEnd - suggestion.cursorOffsetFromEnd)),
                length: 0
            ))
            reportCursor()
        }

        /// Selects the entity pill under a click and reports it. Returns false when the click landed
        /// anywhere else, leaving it to the text view.
        func handleMouseDown(at point: CGPoint) -> Bool {
            guard let textView,
                  let location = characterLocation(for: point, in: textView),
                  let reference = reference(atDisplayLocation: location) else {
                return false
            }

            textView.window?.makeFirstResponder(textView)
            textView.setSelectedRange(NSRange(
                location: displayLocation(forSourceLocation: reference.range.location),
                length: 1
            ))
            reportCursor()
            parent.onEntityTap(reference)
            return true
        }

        /// The height the text takes when wrapped to `width`, never less than one line. Measured on a
        /// copy, so asking doesn't disturb the layout on screen.
        func fittingHeight(forWidth width: CGFloat) -> CGFloat {
            let lineHeight = JinjaTextEditor.font.lineHeight
            guard let textStorage else { return lineHeight }
            let measuredStorage = NSTextStorage(attributedString: textStorage)
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(size: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
            textContainer.lineFragmentPadding = 0
            layoutManager.addTextContainer(textContainer)
            measuredStorage.addLayoutManager(layoutManager)
            layoutManager.ensureLayout(for: textContainer)
            return max(layoutManager.usedRect(for: textContainer).height.rounded(.up), lineHeight)
        }

        private func reportCursor() {
            guard let textView else { return }
            let location = sourceLocation(forDisplayLocation: textView.selectedRange().location)
            DispatchQueue.main.async { [weak self] in
                self?.parent.cursorLocation = location
            }
        }

        private func displayText(
            for sourceText: String,
            entityReferences: [JinjaEntityReference]
        ) -> NSAttributedString {
            let highlighted = JinjaSyntaxHighlighter.highlight(sourceText, font: JinjaTextEditor.font)
            let result = NSMutableAttributedString()
            displayEntityRanges = []

            var sourceLocation = 0
            let sourceLength = (sourceText as NSString).length
            let references = entityReferences
                .filter { $0.range.location >= 0 && NSMaxRange($0.range) <= sourceLength }
                .sorted { $0.range.location < $1.range.location }

            for reference in references where reference.range.location >= sourceLocation {
                if reference.range.location > sourceLocation {
                    result.append(highlighted.attributedSubstring(
                        from: NSRange(location: sourceLocation, length: reference.range.location - sourceLocation)
                    ))
                }

                let displayLocation = result.length
                let attachment = NSTextAttachment()
                attachment.image = pillImage(for: reference)
                attachment.bounds = CGRect(
                    x: 0,
                    y: JinjaTextEditor.font.descender - 4,
                    width: attachment.image?.size.width ?? 0,
                    height: attachment.image?.size.height ?? 0
                )

                let chip = NSMutableAttributedString(attachment: attachment)
                chip.addAttribute(
                    .jinjaEntityReference,
                    value: reference,
                    range: NSRange(location: 0, length: chip.length)
                )
                result.append(chip)
                displayEntityRanges.append((NSRange(location: displayLocation, length: chip.length), reference))
                sourceLocation = NSMaxRange(reference.range)
            }

            if sourceLocation < sourceLength {
                result.append(highlighted.attributedSubstring(
                    from: NSRange(location: sourceLocation, length: sourceLength - sourceLocation)
                ))
            }

            return result
        }

        private func sourceText(from attributedText: NSAttributedString) -> String {
            let result = NSMutableString()
            let nsString = attributedText.string as NSString
            var location = 0

            while location < attributedText.length {
                var effectiveRange = NSRange()
                if let reference = attributedText.attribute(
                    .jinjaEntityReference,
                    at: location,
                    effectiveRange: &effectiveRange
                ) as? JinjaEntityReference {
                    result.append(reference.entityId)
                    location = NSMaxRange(effectiveRange)
                } else {
                    let character = nsString.substring(with: NSRange(location: location, length: 1))
                    if character != "\u{FFFC}" {
                        result.append(character)
                    }
                    location += 1
                }
            }

            return result as String
        }

        private func reference(atDisplayLocation location: Int) -> JinjaEntityReference? {
            displayEntityRanges.first { NSLocationInRange(location, $0.displayRange) }?.reference
        }

        private func sourceLocation(forDisplayLocation displayLocation: Int) -> Int {
            var adjustment = 0
            for item in displayEntityRanges {
                if displayLocation <= item.displayRange.location {
                    break
                } else if NSLocationInRange(displayLocation, item.displayRange) {
                    return item.reference.range.location
                } else {
                    adjustment += item.reference.range.length - item.displayRange.length
                }
            }
            return max(0, displayLocation + adjustment)
        }

        private func displayLocation(forSourceLocation sourceLocation: Int) -> Int {
            var adjustment = 0
            for item in displayEntityRanges {
                if sourceLocation <= item.reference.range.location {
                    break
                } else if sourceLocation <= NSMaxRange(item.reference.range) {
                    return item.displayRange.location + item.displayRange.length
                } else {
                    adjustment += item.reference.range.length - item.displayRange.length
                }
            }
            return max(0, sourceLocation - adjustment)
        }

        private func pillImage(for reference: JinjaEntityReference) -> UIImage {
            let titleFont = UIFont.systemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .footnote).pointSize,
                weight: .medium
            )
            let subtitleFont = UIFont.preferredFont(forTextStyle: .caption2)
            let horizontalPadding: CGFloat = 12
            let verticalPadding: CGFloat = 5
            let maxWidth: CGFloat = 165
            let titleWidth = (reference.name as NSString).size(withAttributes: [.font: titleFont]).width
            let subtitleWidth = reference.subtitle.map {
                ($0 as NSString).size(withAttributes: [.font: subtitleFont]).width
            } ?? 0
            let contentWidth = min(max(titleWidth, subtitleWidth), maxWidth - (horizontalPadding * 2))
            let hasSubtitle = reference.subtitle?.isEmpty == false
            let height: CGFloat = hasSubtitle ? 38 : 26
            let size = CGSize(width: contentWidth + (horizontalPadding * 2), height: height)
            let renderer = UIGraphicsImageRenderer(size: size)

            // The pill is a bitmap, so its colors are fixed when it is drawn: draw it for the appearance
            // the editor is shown in.
            var image = UIImage(size: size)
            (textView?.effectiveAppearance ?? NSApp.effectiveAppearance).performAsCurrentDrawingAppearance {
                image = renderer.image { _ in
                    UIColor.tertiaryFill.setFill()
                    UIBezierPath(
                        roundedRect: CGRect(origin: .zero, size: size),
                        xRadius: height / 2,
                        yRadius: height / 2
                    ).fill()

                    let titleRect = CGRect(
                        x: horizontalPadding,
                        y: hasSubtitle ? verticalPadding : 5,
                        width: contentWidth,
                        height: titleFont.lineHeight
                    )
                    draw(reference.name, in: titleRect, font: titleFont, color: .label)

                    if let subtitle = reference.subtitle, !subtitle.isEmpty {
                        let subtitleRect = CGRect(
                            x: horizontalPadding,
                            y: verticalPadding + titleFont.lineHeight - 1,
                            width: contentWidth,
                            height: subtitleFont.lineHeight
                        )
                        draw(subtitle, in: subtitleRect, font: subtitleFont, color: .secondaryLabel)
                    }
                }
            }
            return image
        }

        private func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingTail
            (text as NSString).draw(in: rect, withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle,
            ])
        }

        private func characterLocation(for point: CGPoint, in textView: NSTextView) -> Int? {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer,
                  layoutManager.numberOfGlyphs > 0 else {
                return nil
            }

            var location = point
            location.x -= textView.textContainerOrigin.x
            location.y -= textView.textContainerOrigin.y

            let glyphIndex = layoutManager.glyphIndex(for: location, in: textContainer)
            let glyphRange = NSRange(location: glyphIndex, length: 1)
            let glyphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            guard glyphRect.insetBy(dx: -4, dy: -6).contains(location) else { return nil }

            return layoutManager.characterIndexForGlyph(at: glyphIndex)
        }
    }
}
#else
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
    /// Known entity id ranges inside the current text, rendered as tappable inline pills.
    var entityReferences: [JinjaEntityReference] = []
    /// Called when the user taps one of the inline entity pills.
    var onEntityTap: (JinjaEntityReference) -> Void = { _ in }
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
        let tapRecognizer = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tapRecognizer.cancelsTouchesInView = false
        textView.addGestureRecognizer(tapRecognizer)
        context.coordinator.textView = textView
        context.coordinator.applyHighlighting(text, entityReferences: entityReferences)
        if autoFocus {
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
            }
        }
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.appliedSourceText != text || context.coordinator
            .appliedEntityReferences != entityReferences {
            context.coordinator.applyHighlighting(text, entityReferences: entityReferences)
        }
        if let insertion = pendingInsertion {
            context.coordinator.scheduleInsertion(insertion)
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
        var appliedSourceText = ""
        var appliedEntityReferences: [JinjaEntityReference] = []
        private var displayEntityRanges: [(displayRange: NSRange, reference: JinjaEntityReference)] = []
        private var scheduledInsertion: JinjaTemplateSuggestion?

        init(parent: JinjaTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            let sourceText = sourceText(from: textView.attributedText)
            parent.text = sourceText
            applyHighlighting(sourceText, entityReferences: parent.entityReferences)
            reportCursor()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            reportCursor()
        }

        /// Re-applies syntax colors, keeping the cursor where it was.
        func applyHighlighting(_ text: String, entityReferences: [JinjaEntityReference]) {
            guard let textView else { return }
            let selectedSourceLocation = sourceLocation(forDisplayLocation: textView.selectedRange.location)
            appliedSourceText = text
            appliedEntityReferences = entityReferences
            textView.attributedText = displayText(for: text, entityReferences: entityReferences)
            let length = (textView.text as NSString).length
            textView.selectedRange = NSRange(
                location: min(displayLocation(forSourceLocation: selectedSourceLocation), length),
                length: 0
            )
        }

        func scheduleInsertion(_ suggestion: JinjaTemplateSuggestion) {
            guard scheduledInsertion != suggestion else { return }
            scheduledInsertion = suggestion

            DispatchQueue.main.async { [weak self] in
                guard let self, scheduledInsertion == suggestion else { return }
                parent.pendingInsertion = nil
                insert(suggestion)
                scheduledInsertion = nil
            }
        }

        private func insert(_ suggestion: JinjaTemplateSuggestion) {
            guard let textView else { return }
            let nsText = parent.text as NSString
            let cursor = min(parent.cursorLocation, nsText.length)
            let replaceRange: NSRange
            if let replacementRange = suggestion.replacementRange,
               NSMaxRange(replacementRange) <= nsText.length {
                replaceRange = replacementRange
            } else {
                let replacingCount = min(suggestion.replacingCount, cursor)
                replaceRange = NSRange(location: cursor - replacingCount, length: replacingCount)
            }
            let nextText = nsText.replacingCharacters(in: replaceRange, with: suggestion.insertion)
            parent.text = nextText
            applyHighlighting(nextText, entityReferences: parent.entityReferences)
            let insertionEnd = replaceRange.location + (suggestion.insertion as NSString).length
            textView.selectedRange = NSRange(
                location: displayLocation(forSourceLocation: max(0, insertionEnd - suggestion.cursorOffsetFromEnd)),
                length: 0
            )
            reportCursor()
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  let textView,
                  let location = characterLocation(for: recognizer.location(in: textView), in: textView),
                  let reference = reference(atDisplayLocation: location) else {
                return
            }

            textView.selectedRange = NSRange(
                location: displayLocation(forSourceLocation: reference.range.location),
                length: 1
            )
            reportCursor()
            parent.onEntityTap(reference)
        }

        private func reportCursor() {
            guard let textView else { return }
            let location = sourceLocation(forDisplayLocation: textView.selectedRange.location)
            DispatchQueue.main.async { [weak self] in
                self?.parent.cursorLocation = location
            }
        }

        private func displayText(
            for sourceText: String,
            entityReferences: [JinjaEntityReference]
        ) -> NSAttributedString {
            let highlighted = JinjaSyntaxHighlighter.highlight(sourceText, font: JinjaTextEditor.font)
            let result = NSMutableAttributedString()
            displayEntityRanges = []

            var sourceLocation = 0
            let sourceLength = (sourceText as NSString).length
            let references = entityReferences
                .filter { $0.range.location >= 0 && NSMaxRange($0.range) <= sourceLength }
                .sorted { $0.range.location < $1.range.location }

            for reference in references where reference.range.location >= sourceLocation {
                if reference.range.location > sourceLocation {
                    result.append(highlighted.attributedSubstring(
                        from: NSRange(location: sourceLocation, length: reference.range.location - sourceLocation)
                    ))
                }

                let displayLocation = result.length
                let attachment = NSTextAttachment()
                attachment.image = pillImage(for: reference)
                attachment.bounds = CGRect(
                    x: 0,
                    y: JinjaTextEditor.font.descender - 4,
                    width: attachment.image?.size.width ?? 0,
                    height: attachment.image?.size.height ?? 0
                )

                let chip = NSMutableAttributedString(attachment: attachment)
                chip.addAttribute(
                    .jinjaEntityReference,
                    value: reference,
                    range: NSRange(location: 0, length: chip.length)
                )
                result.append(chip)
                displayEntityRanges.append((NSRange(location: displayLocation, length: chip.length), reference))
                sourceLocation = NSMaxRange(reference.range)
            }

            if sourceLocation < sourceLength {
                result.append(highlighted.attributedSubstring(
                    from: NSRange(location: sourceLocation, length: sourceLength - sourceLocation)
                ))
            }

            return result
        }

        private func sourceText(from attributedText: NSAttributedString) -> String {
            let result = NSMutableString()
            let nsString = attributedText.string as NSString
            var location = 0

            while location < attributedText.length {
                var effectiveRange = NSRange()
                if let reference = attributedText.attribute(
                    .jinjaEntityReference,
                    at: location,
                    effectiveRange: &effectiveRange
                ) as? JinjaEntityReference {
                    result.append(reference.entityId)
                    location = NSMaxRange(effectiveRange)
                } else {
                    let character = nsString.substring(with: NSRange(location: location, length: 1))
                    if character != "\u{FFFC}" {
                        result.append(character)
                    }
                    location += 1
                }
            }

            return result as String
        }

        private func reference(atDisplayLocation location: Int) -> JinjaEntityReference? {
            displayEntityRanges.first { NSLocationInRange(location, $0.displayRange) }?.reference
        }

        private func sourceLocation(forDisplayLocation displayLocation: Int) -> Int {
            var adjustment = 0
            for item in displayEntityRanges {
                if displayLocation <= item.displayRange.location {
                    break
                } else if NSLocationInRange(displayLocation, item.displayRange) {
                    return item.reference.range.location
                } else {
                    adjustment += item.reference.range.length - item.displayRange.length
                }
            }
            return max(0, displayLocation + adjustment)
        }

        private func displayLocation(forSourceLocation sourceLocation: Int) -> Int {
            var adjustment = 0
            for item in displayEntityRanges {
                if sourceLocation <= item.reference.range.location {
                    break
                } else if sourceLocation <= NSMaxRange(item.reference.range) {
                    return item.displayRange.location + item.displayRange.length
                } else {
                    adjustment += item.reference.range.length - item.displayRange.length
                }
            }
            return max(0, sourceLocation - adjustment)
        }

        private func pillImage(for reference: JinjaEntityReference) -> UIImage {
            let titleFont = UIFont.preferredFont(forTextStyle: .footnote).withWeight(.medium)
            let subtitleFont = UIFont.preferredFont(forTextStyle: .caption2)
            let horizontalPadding: CGFloat = 12
            let verticalPadding: CGFloat = 5
            let maxWidth: CGFloat = 165
            let titleWidth = (reference.name as NSString).size(withAttributes: [.font: titleFont]).width
            let subtitleWidth = reference.subtitle.map {
                ($0 as NSString).size(withAttributes: [.font: subtitleFont]).width
            } ?? 0
            let contentWidth = min(max(titleWidth, subtitleWidth), maxWidth - (horizontalPadding * 2))
            let hasSubtitle = reference.subtitle?.isEmpty == false
            let height: CGFloat = hasSubtitle ? 38 : 26
            let size = CGSize(width: contentWidth + (horizontalPadding * 2), height: height)
            let renderer = UIGraphicsImageRenderer(size: size)

            return renderer.image { _ in
                UIColor.tertiarySystemFill.setFill()
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: height / 2).fill()

                let titleRect = CGRect(
                    x: horizontalPadding,
                    y: hasSubtitle ? verticalPadding : 5,
                    width: contentWidth,
                    height: titleFont.lineHeight
                )
                draw(reference.name, in: titleRect, font: titleFont, color: .label)

                if let subtitle = reference.subtitle, !subtitle.isEmpty {
                    let subtitleRect = CGRect(
                        x: horizontalPadding,
                        y: verticalPadding + titleFont.lineHeight - 1,
                        width: contentWidth,
                        height: subtitleFont.lineHeight
                    )
                    draw(subtitle, in: subtitleRect, font: subtitleFont, color: .secondaryLabel)
                }
            }
        }

        private func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingTail
            (text as NSString).draw(in: rect, withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle,
            ])
        }

        private func characterLocation(for point: CGPoint, in textView: UITextView) -> Int? {
            var location = point
            location.x -= textView.textContainerInset.left
            location.y -= textView.textContainerInset.top

            let layoutManager = textView.layoutManager
            let textContainer = textView.textContainer
            let glyphIndex = layoutManager.glyphIndex(for: location, in: textContainer)
            let glyphRange = NSRange(location: glyphIndex, length: 1)
            let glyphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            guard glyphRect.insetBy(dx: -4, dy: -6).contains(location) else { return nil }

            return layoutManager.characterIndexForGlyph(at: glyphIndex)
        }
    }
}
#endif

#Preview {
    JinjaTextEditor(
        text: .constant("{{ states('sensor.solar_power') | round(1) }} kW"),
        cursorLocation: .constant(0),
        pendingInsertion: .constant(nil)
    )
    .padding()
}

private extension NSAttributedString.Key {
    static let jinjaEntityReference = NSAttributedString.Key("JinjaEntityReference")
}

#if !os(macOS)
private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight],
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
#endif
