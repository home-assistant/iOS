@testable import HomeAssistant
import SwiftUI
import UIKit
import XCTest

@MainActor
final class JinjaTextEditorTests: XCTestCase {
    private var state: EditorState!
    private var textView: UITextView!

    override func setUp() {
        super.setUp()
        state = EditorState()
        textView = UITextView()
    }

    override func tearDown() {
        state = nil
        textView = nil
        super.tearDown()
    }

    func testHighlightingShowsTheSourceText() {
        let coordinator = makeCoordinator()

        coordinator.applyHighlighting("{{ now() }}", entityReferences: [])

        XCTAssertEqual(textView.text, "{{ now() }}")
        XCTAssertEqual(coordinator.appliedSourceText, "{{ now() }}")
        XCTAssertTrue(coordinator.appliedEntityReferences.isEmpty)
        XCTAssertEqual(textView.selectedRange.length, 0)
    }

    func testEntityReferencesBecomePillsAndRoundTripToTheirIds() {
        let source = "{{ states('light.kitchen') }} lit"
        let reference = JinjaEntityReference(
            entityId: "light.kitchen",
            range: (source as NSString).range(of: "light.kitchen"),
            name: "Kitchen",
            subtitle: "Ground floor"
        )
        let untitled = JinjaEntityReference(
            entityId: "lit",
            range: (source as NSString).range(of: "lit"),
            name: "Lit"
        )
        state.entityReferences = [reference, untitled]
        let coordinator = makeCoordinator()

        coordinator.applyHighlighting(source, entityReferences: [untitled, reference])

        XCTAssertFalse(textView.text.contains("light.kitchen"))
        XCTAssertEqual(textView.text.filter { $0 == "\u{FFFC}" }.count, 2)
        XCTAssertEqual(coordinator.appliedEntityReferences, [untitled, reference])

        coordinator.textViewDidChange(textView)
        XCTAssertEqual(state.text, source, "the pills turn back into their entity ids")
    }

    func testEditingReportsTheTextAndCursor() {
        let coordinator = makeCoordinator()
        coordinator.applyHighlighting("{{ }}", entityReferences: [])

        textView.text = "{{ x }}"
        textView.selectedRange = NSRange(location: 4, length: 0)
        coordinator.textViewDidChange(textView)
        XCTAssertEqual(state.text, "{{ x }}")

        waitForMainQueue()
        XCTAssertEqual(state.cursorLocation, 4)

        textView.selectedRange = NSRange(location: 2, length: 0)
        coordinator.textViewDidChangeSelection(textView)
        waitForMainQueue()
        XCTAssertEqual(state.cursorLocation, 2)
    }

    func testInsertsASuggestionAtTheCursor() {
        state.text = "{{  }}"
        state.cursorLocation = 3
        let coordinator = makeCoordinator()
        coordinator.applyHighlighting(state.text, entityReferences: [])
        let suggestion = JinjaTemplateSuggestion(label: "now", insertion: "now()", cursorOffsetFromEnd: 1)
        state.pendingInsertion = suggestion

        coordinator.scheduleInsertion(suggestion)
        // Scheduling the same insertion twice still inserts it once.
        coordinator.scheduleInsertion(suggestion)
        waitForMainQueue()

        XCTAssertEqual(state.text, "{{ now() }}")
        XCTAssertNil(state.pendingInsertion)
        XCTAssertEqual(textView.text, "{{ now() }}")
        XCTAssertEqual(textView.selectedRange.location, 7)
        XCTAssertEqual(state.cursorLocation, 7)
    }

    func testInsertionReplacesTheTypedPrefix() {
        state.text = "{{ states('li') }}"
        state.cursorLocation = 13
        let coordinator = makeCoordinator()
        coordinator.applyHighlighting(state.text, entityReferences: [])

        coordinator.scheduleInsertion(JinjaTemplateSuggestion(
            label: "light.kitchen",
            insertion: "light.kitchen",
            replacingCount: 2
        ))
        waitForMainQueue()

        XCTAssertEqual(state.text, "{{ states('light.kitchen') }}")
    }

    func testInsertionReplacesAnExplicitRange() {
        let source = "{{ states('light.kitchen') }}"
        let range = (source as NSString).range(of: "light.kitchen")
        state.text = source
        let coordinator = makeCoordinator()
        coordinator.applyHighlighting(source, entityReferences: [])

        coordinator.scheduleInsertion(JinjaTemplateSuggestion(
            label: "light.office",
            insertion: "light.office",
            replacementRange: range
        ))
        waitForMainQueue()

        XCTAssertEqual(state.text, "{{ states('light.office') }}")
    }

    func testRendersInsideSwiftUI() throws {
        let source = "{{ states('light.kitchen') }}"
        let view = JinjaTextEditor(
            text: .constant(source),
            cursorLocation: .constant(0),
            pendingInsertion: .constant(JinjaTemplateSuggestion(label: "x", insertion: "x")),
            entityReferences: [
                JinjaEntityReference(entityId: "light.kitchen", range: (source as NSString).range(of: "light.kitchen")),
            ]
        )
        .frame(width: 300)

        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()
        waitForMainQueue()
        controller.view.layoutIfNeeded()

        let editor = try XCTUnwrap(Self.textView(in: controller.view))
        XCTAssertEqual(editor.font, JinjaTextEditor.font)
        XCTAssertEqual(editor.smartQuotesType, .no)
        XCTAssertFalse(editor.isScrollEnabled)
        XCTAssertTrue(editor.text.contains("\u{FFFC}"))
        XCTAssertGreaterThan(controller.sizeThatFits(in: CGSize(width: 300, height: 1000)).height, 0)

        window.isHidden = true
        window.rootViewController = nil
    }

    // MARK: - Helpers

    private func makeCoordinator() -> JinjaTextEditor.Coordinator {
        let state = state!
        let editor = JinjaTextEditor(
            text: Binding(get: { state.text }, set: { state.text = $0 }),
            cursorLocation: Binding(get: { state.cursorLocation }, set: { state.cursorLocation = $0 }),
            pendingInsertion: Binding(get: { state.pendingInsertion }, set: { state.pendingInsertion = $0 }),
            entityReferences: state.entityReferences
        )
        let coordinator = editor.makeCoordinator()
        coordinator.textView = textView
        return coordinator
    }

    /// The editor reports cursor moves and applies insertions on the next main-queue turn.
    private func waitForMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                drained.fulfill()
            }
        }
        wait(for: [drained], timeout: 5)
    }

    private static func textView(in view: UIView) -> UITextView? {
        if let textView = view as? UITextView {
            return textView
        }
        for subview in view.subviews {
            if let textView = textView(in: subview) {
                return textView
            }
        }
        return nil
    }

    private final class EditorState {
        var text = ""
        var cursorLocation = 0
        var pendingInsertion: JinjaTemplateSuggestion?
        var entityReferences: [JinjaEntityReference] = []
    }
}
