@testable import HomeAssistant
import Shared
import SwiftUI
import Testing

struct GesturesSetupViewTests {
    @MainActor
    @Test func testUI() async throws {
        assertLightDarkSnapshots(of: NavigationView { GesturesSetupView() }, drawHierarchyInKeyWindow: true)
    }

    @MainActor
    @Test func testActionsPickerUI() async throws {
        let selection = HAGestureAction.showSidebar
        assertLightDarkSnapshots(
            of: NavigationView {
                ListPickerContentView(
                    title: L10n.Gestures._1Finger.title,
                    selection: .constant(.init(id: selection.rawValue, title: selection.localizedString)),
                    content: GesturesSetupView.gestureActionsPickerContent
                )
            },
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 390, height: 1250)
        )
    }

    @MainActor
    @Test func testActionsPickerSearchingUI() async throws {
        let selection = HAGestureAction.showSidebar
        assertLightDarkSnapshots(
            of: NavigationView {
                ListPickerContentView(
                    title: L10n.Gestures._1Finger.title,
                    selection: .constant(.init(id: selection.rawValue, title: selection.localizedString)),
                    content: GesturesSetupView.gestureActionsPickerContent,
                    searchTerm: "server"
                )
            },
            drawHierarchyInKeyWindow: true
        )
    }
}
