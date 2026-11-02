@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Hosts the Jinja text view and drives its coordinator the way UIKit would: edits and selection
/// changes flow back to the bindings with entity pills mapped back to their ids, suggestions are
/// inserted at the cursor or over a pill, and taps on a pill report that entity.
@MainActor
struct JinjaTextEditorTests {
    private static let source = "{{ states('light.kitchen') }} and {{ states('sensor.solar') }}"

    @MainActor
    private final class Model: ObservableObject {
        @Published var text: String
        @Published var cursor = 0
        @Published var pending: JinjaTemplateSuggestion?
        @Published var references: [JinjaEntityReference]
        var tapped: [JinjaEntityReference] = []

        init(text: String, references: [JinjaEntityReference] = []) {
            self.text = text
            self.references = references
        }
    }

    private struct Host: View {
        @ObservedObject var model: Model

        var body: some View {
            JinjaTextEditor(
                text: $model.text,
                cursorLocation: $model.cursor,
                pendingInsertion: $model.pending,
                entityReferences: model.references,
                onEntityTap: { model.tapped.append($0) }
            )
            .frame(width: 360)
        }
    }

    /// A tap whose state and location the test decides.
    private final class FakeTap: UITapGestureRecognizer {
        var point: CGPoint = .zero
        var forcedState: UIGestureRecognizer.State = .ended

        override var state: UIGestureRecognizer.State {
            get { forcedState }
            set { forcedState = newValue }
        }

        override func location(in view: UIView?) -> CGPoint {
            point
        }
    }

    private final class Hosted {
        let window: UIWindow
        let host: UIHostingController<Host>

        init(_ model: Model) {
            self.host = UIHostingController(rootView: Host(model: model))
            self.window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
            window.rootViewController = host
            window.isHidden = false
            layout()
        }

        func layout() {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
        }

        var textView: UITextView? {
            Self.find(in: host.view)
        }

        var coordinator: JinjaTextEditor.Coordinator? {
            textView?.delegate as? JinjaTextEditor.Coordinator
        }

        func close() {
            textView?.resignFirstResponder()
            window.isHidden = true
            window.rootViewController = nil
        }

        private static func find(in view: UIView) -> UITextView? {
            if let textView = view as? UITextView { return textView }
            for subview in view.subviews {
                if let found = find(in: subview) { return found }
            }
            return nil
        }
    }

    private func references(in text: String) -> [JinjaEntityReference] {
        let nsText = text as NSString
        return [
            JinjaEntityReference(
                entityId: "light.kitchen",
                range: nsText.range(of: "light.kitchen"),
                name: "Kitchen",
                subtitle: "Ground Floor • Kitchen"
            ),
            JinjaEntityReference(
                entityId: "sensor.solar",
                range: nsText.range(of: "sensor.solar"),
                name: "A very long solar production sensor name that has to be truncated",
                subtitle: nil
            ),
            // Out of range: ignored.
            JinjaEntityReference(entityId: "sun.sun", range: NSRange(location: 500, length: 7)),
        ]
    }

    private func waitUntil(_ hosted: Hosted, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition() {
            if Date() > deadline { return false }
            hosted.layout()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return true
    }

    @Test func entityIdsRenderAsPillsAndMapBackToSource() async throws {
        let model = Model(text: Self.source, references: references(in: Self.source))
        let hosted = Hosted(model)
        defer { hosted.close() }
        let textView = try #require(hosted.textView)
        let coordinator = try #require(hosted.coordinator)

        // Each in-range id becomes a single attachment character.
        let display = textView.attributedText.string
        #expect(display.filter { $0 == "\u{FFFC}" }.count == 2)
        #expect(!display.contains("light.kitchen"))
        #expect(coordinator.appliedSourceText == Self.source)

        // An unchanged edit maps the pills back to their ids.
        coordinator.textViewDidChange(textView)
        #expect(model.text == Self.source)

        // Typing after the pills keeps the ids in the source text.
        textView.textStorage.append(NSAttributedString(string: " W"))
        coordinator.textViewDidChange(textView)
        #expect(model.text == Self.source + " W")

        // A cursor right after the first pill is reported in source coordinates.
        let firstPill = (Self.source as NSString).range(of: "light.kitchen")
        textView.selectedRange = NSRange(location: firstPill.location + 1, length: 0)
        coordinator.textViewDidChangeSelection(textView)
        await #expect(waitUntil(hosted) { model.cursor == NSMaxRange(firstPill) })

        // A cursor on a pill is reported at the pill's start.
        textView.selectedRange = NSRange(location: firstPill.location, length: 0)
        coordinator.textViewDidChangeSelection(textView)
        await #expect(waitUntil(hosted) { model.cursor == firstPill.location })
    }

    @Test func suggestionsAreInsertedAtTheCursor() async throws {
        let text = "{{ states('li"
        let model = Model(text: text)
        let hosted = Hosted(model)
        defer { hosted.close() }
        let textView = try #require(hosted.textView)
        let coordinator = try #require(hosted.coordinator)
        // Report the cursor through the text view, queued behind the editor's own initial report.
        let end = (text as NSString).length
        textView.selectedRange = NSRange(location: end, length: 0)
        coordinator.textViewDidChangeSelection(textView)
        await #expect(waitUntil(hosted) { model.cursor == end })

        model.pending = JinjaTemplateSuggestion(
            label: "light.kitchen",
            insertion: "light.kitchen') }}",
            replacingCount: 2,
            cursorOffsetFromEnd: 5
        )
        hosted.layout()

        await #expect(waitUntil(hosted) { model.pending == nil })
        #expect(model.text == "{{ states('light.kitchen') }}")
        await #expect(waitUntil(hosted) { model.cursor == (model.text as NSString).length - 5 })
    }

    @Test func aSuggestionCanReplaceAPill() async throws {
        let model = Model(text: Self.source, references: references(in: Self.source))
        let hosted = Hosted(model)
        defer { hosted.close() }
        let pill = (Self.source as NSString).range(of: "light.kitchen")

        model.pending = JinjaTemplateSuggestion(
            label: "light.bedroom",
            insertion: "light.bedroom",
            replacementRange: pill
        )
        hosted.layout()

        await #expect(waitUntil(hosted) { model.pending == nil })
        #expect(model.text == Self.source.replacingOccurrences(of: "light.kitchen", with: "light.bedroom"))
    }

    @Test func tappingAPillReportsItsEntity() throws {
        let model = Model(text: Self.source, references: references(in: Self.source))
        let hosted = Hosted(model)
        defer { hosted.close() }
        let textView = try #require(hosted.textView)
        let coordinator = try #require(hosted.coordinator)
        let pill = (Self.source as NSString).range(of: "light.kitchen")

        let layoutManager = textView.layoutManager
        layoutManager.ensureLayout(for: textView.textContainer)
        let pillRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: pill.location, length: 1),
            in: textView.textContainer
        )
        let plainRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: 0, length: 1),
            in: textView.textContainer
        )

        let tap = FakeTap()

        // A tap that hasn't ended, one on plain text and one far outside the text do nothing.
        tap.point = CGPoint(x: pillRect.midX, y: pillRect.midY)
        tap.forcedState = .began
        coordinator.handleTap(tap)
        tap.forcedState = .ended
        tap.point = CGPoint(x: plainRect.midX, y: plainRect.midY)
        coordinator.handleTap(tap)
        tap.point = CGPoint(x: 5000, y: 5000)
        coordinator.handleTap(tap)
        #expect(model.tapped.isEmpty)

        tap.point = CGPoint(x: pillRect.midX, y: pillRect.midY)
        coordinator.handleTap(tap)
        #expect(model.tapped.map(\.entityId) == ["light.kitchen"])
        #expect(textView.selectedRange == NSRange(location: pill.location, length: 1))
    }

    @Test func changingTheTextOrReferencesReappliesHighlighting() throws {
        let model = Model(text: "plain text")
        let hosted = Hosted(model)
        defer { hosted.close() }
        let coordinator = try #require(hosted.coordinator)

        model.text = Self.source
        hosted.layout()
        #expect(coordinator.appliedSourceText == Self.source)

        model.references = references(in: Self.source)
        hosted.layout()
        #expect(coordinator.appliedEntityReferences.count == 3)
        #expect(hosted.textView?.attributedText.string.contains("light.kitchen") == false)
    }

    @Test func highlighterColorsEachKindOfToken() {
        let font = JinjaTextEditor.font
        let text = "Hi {% if is_state('sun.sun', \"above\") and 1.5 > 2 %}{{ x | round(1) }}{% endif %} {{ open"
        let reference = JinjaEntityReference(
            entityId: "sun.sun",
            range: (text as NSString).range(of: "sun.sun")
        )
        let outOfRange = JinjaEntityReference(entityId: "x", range: NSRange(location: 400, length: 1))
        let highlighted = JinjaSyntaxHighlighter.highlight(text, font: font, entityReferences: [reference, outOfRange])

        func color(of token: String) -> UIColor? {
            let location = (text as NSString).range(of: token).location
            return highlighted.attribute(.foregroundColor, at: location, effectiveRange: nil) as? UIColor
        }

        #expect(highlighted.string == text)
        #expect(color(of: "Hi") == .secondaryLabel)
        #expect(color(of: "if") == .systemPurple)
        #expect(color(of: "is_state") == .systemTeal)
        #expect(color(of: "1.5") == .systemBlue)
        #expect(color(of: "\"above\"") == .systemOrange)
        #expect(color(of: "{%") == .systemPink)
        let referenceLocation = reference.range.location
        #expect(highlighted.attribute(.backgroundColor, at: referenceLocation, effectiveRange: nil) != nil)
        // The unterminated expression is still highlighted as code.
        #expect(color(of: "open") == .label)
    }

    @Test func entitySuggestionPillsRender() {
        let items = [
            JinjaEntitySuggestionsView.Item(
                suggestion: .init(label: "sensor.solar", insertion: "sensor.solar"),
                name: "Solar",
                subtitle: "Garage"
            ),
            JinjaEntitySuggestionsView.Item(
                suggestion: .init(label: "light.kitchen", insertion: "light.kitchen"),
                name: "Kitchen",
                subtitle: nil
            ),
        ]
        #expect(items.map(\.id) == ["sensor.solarsensor.solar", "light.kitchenlight.kitchen"])
        let host = UIHostingController(rootView: JinjaEntitySuggestionsView(
            items: items,
            onSelect: { _ in },
            onMore: {}
        ))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        window.rootViewController = host
        window.isHidden = false
        host.view.layoutIfNeeded()
        #expect(host.view.intrinsicContentSize.height > 0 || host.view.bounds.height > 0)
        window.isHidden = true
        window.rootViewController = nil
    }
}
