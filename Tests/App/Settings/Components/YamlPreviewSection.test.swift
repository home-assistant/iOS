@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// The YAML preview opens its full-screen sheet and share sheet from its rows, and the notification
/// identifier helpers keep identifiers to letters, digits and underscores.
@Suite(.isolatedEnvironment)
@MainActor
struct YamlPreviewSectionTests {
    private static let yaml = """
    actions:
      - identifier: OPEN_GATE
        title: Open gate
    """

    /// Tapping a row only asks for its sheet: SwiftUI presents sheets through UIKit, which an off-screen
    /// window doesn't reliably do, so the test doesn't wait for them and renders the preview sheet's
    /// content on its own instead.
    @Test func rowsAskForTheirSheetsAndThePreviewRenders() async {
        let harness = await SettingsScreenHarness.show(List {
            YamlPreviewSection(header: "YAML", yaml: Self.yaml)
            YamlPreviewSection(header: "Custom", shareTitle: "Share this", yaml: "key: value")
        }, inNavigationStack: false)
        #expect(harness.rows.count == 4)

        await harness.tapRow(IndexPath(item: 1, section: 1))
        await harness.dismissPresented()
        await harness.tapRow(IndexPath(item: 0, section: 0))
        await harness.close()

        let preview = await SettingsScreenHarness.show(YamlCodePreviewView(yaml: Self.yaml), inNavigationStack: false)
        // Close and copy. Only close is tapped (outside a presentation it does nothing): copy writes the
        // pasteboard, which other tests read.
        #expect(preview.barButtons.count == 2)
        if let item = preview.navigationController?.topViewController?.navigationItem,
           let close = (item.leftBarButtonItems ?? []).first ?? item.leadingItemGroups.flatMap(\.barButtonItems).first,
           let index = preview.barButtons.firstIndex(where: { $0 === close }) {
            await preview.tapBarButton(index)
        }
        await preview.close()
    }

    /// Copy puts the YAML on the pasteboard. `.sharedState`: the pasteboard is process-wide, and
    /// other tests read it.
    @Test(.sharedState) func copyPutsTheYAMLOnThePasteboard() async {
        let pasteboard = UIPasteboard.general
        let previous = pasteboard.string
        defer { pasteboard.string = previous ?? "" }

        let preview = await SwiftUIScreenDriver.show(YamlCodePreviewView(yaml: Self.yaml), inNavigationStack: false)
        defer { preview.close() }
        let pressed = await preview.tapBarButton(titled: L10n.Nfc.Detail.copy)
        #expect(pressed)
        #expect(pasteboard.string == Self.yaml)
    }

    @Test func identifiersAreSanitizedAndValidated() {
        #expect(NotificationIdentifierField.sanitize("open gate!", uppercaseOnly: false) == "open_gate")
        // Lowercase letters are dropped rather than uppercased when only uppercase is allowed.
        #expect(NotificationIdentifierField.sanitize("Open Gate 2", uppercaseOnly: true) == "O_G_2")
        #expect(NotificationIdentifierField.sanitize("Ação 1", uppercaseOnly: false) == "Ao_1")
        #expect(NotificationIdentifierField.isValid("OPEN_GATE", uppercaseOnly: true))
        #expect(!NotificationIdentifierField.isValid("open_gate", uppercaseOnly: true))
        #expect(NotificationIdentifierField.isValid("open_gate", uppercaseOnly: false))
        #expect(!NotificationIdentifierField.isValid("", uppercaseOnly: false))
    }

    @Test func identifierFieldSanitizesWhatIsTyped() async {
        var category = "category"
        var action = ""
        let harness = await SettingsScreenHarness.show(List {
            NotificationIdentifierTextField(
                title: "Category",
                text: Binding(get: { category }, set: { category = $0 }),
                uppercaseOnly: false
            )
            NotificationIdentifierTextField(
                title: "Action",
                text: Binding(get: { action }, set: { action = $0 }),
                uppercaseOnly: true,
                isDisabled: false
            )
            NotificationIdentifierTextField(
                title: "Locked",
                text: .constant("bad id"),
                uppercaseOnly: true,
                isDisabled: true
            )
        })
        await harness.type("OPEN gate 1")
        #expect(category == "OPEN_gate_1")
        #expect(action == "OPEN__1")
        await harness.close()
    }
}
