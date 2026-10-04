@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

/// Notification category and action identifiers only take letters, digits and underscores, and
/// action identifiers are uppercase.
@MainActor
struct NotificationIdentifierFieldTests {
    @Test func sanitizingReplacesSpacesAndDropsOtherCharacters() {
        #expect(NotificationIdentifierField.sanitize("my category-1!", uppercaseOnly: false) == "my_category1")
        #expect(NotificationIdentifierField.sanitize("Été 2", uppercaseOnly: false) == "t_2")
    }

    @Test func sanitizingUppercaseOnlyDropsLowercaseLetters() {
        // Lowercase letters are outside the allowed set, so they are dropped rather than uppercased.
        #expect(NotificationIdentifierField.sanitize("OPEN door", uppercaseOnly: true) == "OPEN_")
        #expect(NotificationIdentifierField.sanitize("ACTION_1", uppercaseOnly: true) == "ACTION_1")
    }

    @Test func validityRequiresANonEmptyAlreadySanitizedValue() {
        #expect(NotificationIdentifierField.isValid("", uppercaseOnly: false) == false)
        #expect(NotificationIdentifierField.isValid("my_category", uppercaseOnly: false))
        #expect(NotificationIdentifierField.isValid("my category", uppercaseOnly: false) == false)
        #expect(NotificationIdentifierField.isValid("ACTION", uppercaseOnly: true))
        #expect(NotificationIdentifierField.isValid("Action", uppercaseOnly: true) == false)
    }

    @Test func textFieldRendersValidInvalidAndDisabledValues() {
        render(Form {
            NotificationIdentifierTextField(title: "Identifier", text: .constant("VALID_1"), uppercaseOnly: true)
            NotificationIdentifierTextField(title: "Identifier", text: .constant("not valid"), uppercaseOnly: false)
            NotificationIdentifierTextField(
                title: "Identifier",
                text: .constant(""),
                uppercaseOnly: false,
                isDisabled: true
            )
        })
    }

    @Test func yamlPreviewRendersTheSectionAndTheFullScreenPreview() {
        let yaml = "- platform: tag\n  tag_id: abc123"
        render(Form {
            YamlPreviewSection(header: "Example", yaml: yaml)
            YamlPreviewSection(header: "Example", shareTitle: "Share it", yaml: yaml)
        })
        render(YamlCodePreviewView(yaml: yaml))
    }

    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }
}
