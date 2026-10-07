@testable import HomeAssistant

import Shared
import SharedTesting

import SwiftUI
import Testing

/// The sheet behind a magic item's "perform action" behavior: the actions its own server offers,
/// each with the server's icon, the chosen one ticked, and what stands in while there is nothing to
/// list yet.
@MainActor
struct ServerActionPickerListTests {
    @Test func listsTheServersActionsWithTheChosenOneTicked() {
        assertSnapshots(actions: Self.actions, selectedActionId: "light.turn_on")
    }

    /// Searching matches the friendly name and the `domain.service` pair alike.
    @Test func searchNarrowsToMatchingActions() {
        assertSnapshots(actions: Self.actions, searchTerm: "toggle")
    }

    /// A search short enough to be ambiguous (two characters or fewer) filters nothing, so the whole
    /// list stays visible while the user is still typing.
    @Test func shortSearchLeavesEveryActionListed() {
        assertSnapshots(actions: Self.actions, searchTerm: "to")
    }

    @Test func spinnerStandsInWhileTheServerIsAsked() {
        assertSnapshots(actions: [], isLoading: true)
    }

    /// Nothing to choose from — the server was unreachable, or exposed no action.
    @Test func saysWhenTheServerOfferedNoAction() {
        assertSnapshots(actions: [])
    }

    /// The last one carries no icon on purpose: an action the server describes without one falls
    /// back to the bolt, so no row is ever left with a gap where the icon should be.
    private static let actions: [IntentActionDefinition] = [
        .init(
            domain: "light",
            service: "turn_on",
            name: "Turn on",
            actionDescription: nil,
            icon: "mdi:lightbulb-on"
        ),
        .init(
            domain: "light",
            service: "toggle",
            name: "Toggle",
            actionDescription: nil,
            icon: "mdi:lightbulb"
        ),
        .init(
            domain: "notify",
            service: "persistent_notification",
            name: "Send a persistent notification",
            actionDescription: nil
        ),
    ]

    private func assertSnapshots(
        actions: [IntentActionDefinition],
        isLoading: Bool = false,
        searchTerm: String = "",
        selectedActionId: String? = nil,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        assertLightDarkSnapshots(
            of: NavigationView {
                ServerActionPickerList(
                    actions: actions,
                    isLoading: isLoading,
                    searchTerm: .constant(searchTerm),
                    selectedActionId: selectedActionId,
                    onSelect: { _ in },
                    onReload: {},
                    onClose: {}
                )
            },
            drawHierarchyInKeyWindow: true,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }
}
