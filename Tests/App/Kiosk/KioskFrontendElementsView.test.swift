@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

struct KioskFrontendElementsViewTests {
    @MainActor
    @Test func screenShowsEveryElementWithTheDefaultsSelected() {
        assertLightDarkSnapshots(
            of: NavigationView {
                KioskFrontendElementsView(hiddenElements: .constant(KioskFrontendElement.defaultHidden))
            },
            drawHierarchyInKeyWindow: true
        )
    }

    @MainActor
    @Test func screenShowsAnAllClearChoice() {
        assertLightDarkSnapshots(
            of: NavigationView {
                KioskFrontendElementsView(hiddenElements: .constant([]))
            },
            drawHierarchyInKeyWindow: true
        )
    }
}
