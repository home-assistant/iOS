@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

@Suite(.sharedState)
struct GesturesSetupViewTests {
    @MainActor
    @Test func testUI() async throws {
        assertLightDarkSnapshots(of: NavigationView { GesturesSetupView() }, drawHierarchyInKeyWindow: true)
    }

    @MainActor
    @Test func testActionsPickerUI() async throws {
        let selection = HAGestureAction.showSidebar
        assertLightDarkSnapshots(
            of: ListPickerContentView(
                title: L10n.Gestures._1Finger.title,
                selection: .constant(.init(id: selection.rawValue, title: selection.localizedString)),
                content: GesturesSetupView.gestureActionsPickerContent
            ),
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 390, height: 1250)
        )
    }

    @MainActor
    @Test func testActionsPickerSearchingUI() async throws {
        let selection = HAGestureAction.showSidebar
        assertLightDarkSnapshots(
            of: ListPickerContentView(
                title: L10n.Gestures._1Finger.title,
                selection: .constant(.init(id: selection.rawValue, title: selection.localizedString)),
                content: GesturesSetupView.gestureActionsPickerContent,
                searchTerm: "server"
            ),
            drawHierarchyInKeyWindow: true
        )
    }

    /// Picking an action in a gesture's list stores it, for a plain gesture and a swipe alike; Reset
    /// only asks for confirmation.
    @MainActor
    @Test func pickingAnActionStoresIt() async throws {
        let previous = Current.settingsStore.gestures
        defer { Current.settingsStore.gestures = previous }
        Current.settingsStore.gestures = .defaultGestures

        let driver = await SwiftUIScreenDriver.show(GesturesSetupView())
        defer { driver.close() }

        // The first plain gesture, then the first swipe to the left, each set to the second action of
        // the first category.
        let picked = try #require(GesturesSetupView.gestureActionsPickerContent.sections.first?.items[1])
        let firstOf: (UISwipeGestureRecognizer.Direction?) -> AppGesture? = { direction in
            AppGesture.allCases.filter { $0.direction == direction }
                .sorted { $0.setupScreenOrder < $1.setupScreenOrder }.first
        }
        for (section, gesture) in [(1, firstOf(nil)), (2, firstOf(.left))] {
            let gesture = try #require(gesture)
            try await #require(driver.push(IndexPath(item: 0, section: section)))
            await driver.tapRow(IndexPath(item: 1, section: 0))
            await driver.popToRoot()
            #expect(Current.settingsStore.gestures[gesture]?.rawValue == picked.id)
        }

        await driver.tapBarButton(titled: L10n.Gestures.Reset.title)
        await driver.dismissPresented()
    }

    /// Resetting puts every gesture back to its default and republishes the stored settings.
    @Test func resettingRestoresTheDefaultGestures() throws {
        let previous = Current.settingsStore.gestures
        defer { Current.settingsStore.gestures = previous }
        let gesture = try #require(AppGesture.allCases.first)

        let viewModel = GesturesSetupViewModel()
        viewModel.setSelection(for: gesture, newValue: .none)
        viewModel.resetGestures()
        #expect(viewModel.settings == [AppGesture: HAGestureAction].defaultGestures)
        #expect(Current.settingsStore.gestures == [AppGesture: HAGestureAction].defaultGestures)
    }
}
