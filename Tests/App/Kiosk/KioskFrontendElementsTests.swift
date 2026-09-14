import Foundation
@testable import Shared
import Testing

struct KioskFrontendElementsTests {
    // The raw values travel to the frontend as `excluded_elements`, so they are a wire contract with
    // `KIOSK_ELEMENTS` in the frontend repository, not names we are free to rename.
    @Test func elementRawValuesMatchTheFrontendNames() {
        #expect(KioskFrontendElement.allCases.map(\.rawValue) == [
            "sidebar",
            "sidebar_button",
            "dashboard_tabs",
            "dashboard_add_button",
            "dashboard_search_button",
            "dashboard_assist_button",
            "dashboard_edit_button",
            "app_panel_header",
        ])
    }

    // The frontend hides this exact set for a client that only sends `enable`, so the default has to
    // match it: the switch looks the same whether or not the frontend understands the element list.
    @Test func defaultHiddenMatchesTheFrontendPreset() {
        #expect(KioskFrontendElement.defaultHidden == [
            .sidebar,
            .sidebarButton,
            .dashboardAddButton,
            .dashboardSearchButton,
            .dashboardEditButton,
            .appPanelHeader,
        ])
        #expect(!KioskFrontendElement.defaultHidden.contains(.dashboardAssistButton))
        #expect(!KioskFrontendElement.defaultHidden.contains(.dashboardTabs))
    }

    @Test func hidesNothingWhileKioskModeIsOff() {
        let settings = KioskSettings(enabled: false, removeHeaderAndSidebar: true)

        #expect(settings.frontendElementsToHide(nativeTabBar: false).isEmpty)
    }

    @Test func hidesNothingWhileTheSwitchIsOff() {
        let settings = KioskSettings(enabled: true, removeHeaderAndSidebar: false)

        #expect(settings.frontendElementsToHide(nativeTabBar: false).isEmpty)
    }

    @Test func hidesTheChosenElements() {
        let settings = KioskSettings(
            enabled: true,
            removeHeaderAndSidebar: true,
            hiddenFrontendElements: [.sidebarButton, .dashboardAssistButton]
        )

        #expect(settings.frontendElementsToHide(nativeTabBar: false) == [
            .sidebarButton,
            .dashboardAssistButton,
        ])
    }

    // The native tab bar's own tabs reach every sidebar page, so it only needs the hamburger gone.
    // It used to borrow the whole kiosk set and took the add, search and edit buttons with it.
    @Test func nativeTabBarHidesOnlyTheSidebarButton() {
        let settings = KioskSettings(enabled: false)

        #expect(settings.frontendElementsToHide(nativeTabBar: true) == [.sidebarButton])
    }

    @Test func nativeTabBarAndKioskModeCombine() {
        let settings = KioskSettings(
            enabled: true,
            removeHeaderAndSidebar: true,
            hiddenFrontendElements: [.dashboardEditButton]
        )

        #expect(settings.frontendElementsToHide(nativeTabBar: true) == [
            .dashboardEditButton,
            .sidebarButton,
        ])
    }

    // Every element gets a row on the settings screen, so a case added without its copy would
    // otherwise ship a blank row.
    @Test func everyElementHasATitleAndAnIcon() {
        for element in KioskFrontendElement.allCases {
            #expect(!element.title.isEmpty)
            #expect(element.title != element.rawValue, "\(element.rawValue) is missing its localized title")
            #expect(!element.icon.name.isEmpty)
        }
    }

    @Test func anEmptyChoiceHidesNothingEvenWithTheSwitchOn() {
        let settings = KioskSettings(
            enabled: true,
            removeHeaderAndSidebar: true,
            hiddenFrontendElements: []
        )

        #expect(settings.frontendElementsToHide(nativeTabBar: false).isEmpty)
    }

    @Test func hidingAnElementAddsItOnce() {
        var hidden: Set<KioskFrontendElement> = [.sidebar]

        hidden.setHidden(true, for: .dashboardTabs)
        hidden.setHidden(true, for: .dashboardTabs)

        #expect(hidden == [.sidebar, .dashboardTabs])
    }

    @Test func showingAnElementRemovesOnlyThatElement() {
        var hidden: Set<KioskFrontendElement> = [.sidebar, .dashboardTabs]

        hidden.setHidden(false, for: .dashboardTabs)
        hidden.setHidden(false, for: .appPanelHeader)

        #expect(hidden == [.sidebar])
    }
}
