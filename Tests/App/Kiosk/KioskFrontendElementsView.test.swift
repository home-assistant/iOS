@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

@MainActor
struct KioskFrontendElementsViewTests {
    // Taller than a phone so the footer below the last switch is part of the picture.
    @Test func showsEveryElementWithTheDefaultsSelected() {
        assertLightDarkSnapshots(
            of: NavigationView {
                KioskFrontendElementsView(hiddenElements: .constant(KioskFrontendElement.defaultHidden))
            },
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 390, height: 1200)
        )
    }

    @Test func showsEveryElementWithNothingSelected() {
        assertLightDarkSnapshots(
            of: NavigationView {
                KioskFrontendElementsView(hiddenElements: .constant([]))
            },
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 390, height: 1200)
        )
    }

    /// Goes through the binding each switch is built from, so a setter that stopped inserting or
    /// removing the element would fail here rather than only in the app.
    @Test func switchingAnElementOnAndOffWritesThroughTheBinding() {
        var hidden: Set<KioskFrontendElement> = [.sidebar]
        let view = KioskFrontendElementsView(hiddenElements: Binding(get: { hidden }, set: { hidden = $0 }))
        let dashboardTabs = view.binding(for: .dashboardTabs)

        dashboardTabs.wrappedValue = true
        #expect(hidden == [.sidebar, .dashboardTabs])
        #expect(dashboardTabs.wrappedValue)

        dashboardTabs.wrappedValue = false
        #expect(hidden == [.sidebar])
        #expect(!dashboardTabs.wrappedValue)
    }
}
