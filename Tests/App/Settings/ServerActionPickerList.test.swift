@testable import HomeAssistant

import Shared
import SharedTesting

import SwiftUI
import Testing

/// The sheet behind a magic item's "perform action" behavior: each server's actions, the chosen one
/// ticked, and what stands in while there is nothing to list yet.
@MainActor
struct ServerActionPickerListTests {
    /// Two servers can offer the same `domain.service`, so the tick has to follow the server the
    /// action was chosen on — here the second one — not just the id.
    @Test func listsEveryServersActionsWithTheChosenOneTicked() {
        assertSnapshots(
            groups: Self.groups,
            selectedServerId: "2",
            selectedActionId: "light.turn_on"
        )
    }

    /// Searching matches the friendly name and the `domain.service` pair alike, across every server.
    @Test func searchNarrowsToMatchingActions() {
        assertSnapshots(groups: Self.groups, searchTerm: "toggle")
    }

    /// A search short enough to be ambiguous (two characters or fewer) filters nothing, so the whole
    /// list stays visible while the user is still typing.
    @Test func shortSearchLeavesEveryActionListed() {
        assertSnapshots(groups: Self.groups, searchTerm: "to")
    }

    @Test func spinnerStandsInWhileTheServersAreAsked() {
        assertSnapshots(groups: [], isLoading: true)
    }

    /// Nothing to choose from — every server was unreachable, or none exposed an action.
    @Test func saysWhenNoServerOfferedAnyAction() {
        assertSnapshots(groups: [])
    }

    private static let groups: [ServerActionGroup] = [
        .init(
            id: "1",
            name: "Home",
            actions: [
                .init(domain: "light", service: "turn_on", name: "Turn on", actionDescription: nil),
                .init(domain: "light", service: "toggle", name: "Toggle", actionDescription: nil),
                .init(
                    domain: "notify",
                    service: "persistent_notification",
                    name: "Send a persistent notification",
                    actionDescription: nil
                ),
            ]
        ),
        .init(
            id: "2",
            name: "Cabin",
            actions: [
                .init(domain: "light", service: "turn_on", name: "Turn on", actionDescription: nil),
                .init(domain: "script", service: "toggle", name: "Toggle", actionDescription: nil),
            ]
        ),
    ]

    private func assertSnapshots(
        groups: [ServerActionGroup],
        isLoading: Bool = false,
        searchTerm: String = "",
        selectedServerId: String? = nil,
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
                    groups: groups,
                    isLoading: isLoading,
                    searchTerm: .constant(searchTerm),
                    selectedServerId: selectedServerId,
                    selectedActionId: selectedActionId,
                    onSelect: { _, _ in },
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
