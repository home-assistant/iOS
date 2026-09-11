@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

@MainActor
struct MagicItemConfigurationRowTests {
    /// The handle is hidden until the section is put in edit mode, so a resting list reads cleanly.
    @Test func rowHidesTheReorderHandleWhileResting() {
        assertLightDarkSnapshots(of: list(isReorderIndicatorVisible: false), drawHierarchyInKeyWindow: true)
    }

    @Test func rowShowsTheReorderHandleWhileEditing() {
        assertLightDarkSnapshots(of: list(isReorderIndicatorVisible: true), drawHierarchyInKeyWindow: true)
    }

    /// An assist prompt has no entity context, so its subtitle is the prompt it sends instead.
    @Test func assistPromptRowShowsThePromptItSends() {
        assertLightDarkSnapshots(
            of: List {
                MagicItemConfigurationRow(
                    item: .init(
                        id: "prompt-1",
                        serverId: "1",
                        type: .assistPrompt,
                        displayText: "Good night",
                        assistPrompt: "Turn everything off downstairs"
                    ),
                    info: .init(id: "1-prompt-1", name: "Assist prompt", iconName: ""),
                    isReorderIndicatorVisible: false
                )
            },
            drawHierarchyInKeyWindow: true
        )
    }

    /// Information that hasn't loaded yet leaves the row with the item's id as its name.
    @Test func rowWithoutInformationFallsBackToTheItemId() {
        assertLightDarkSnapshots(
            of: List {
                MagicItemConfigurationRow(
                    item: .init(id: "script.morning", serverId: "1", type: .script),
                    info: nil,
                    isReorderIndicatorVisible: false
                )
            },
            drawHierarchyInKeyWindow: true
        )
    }

    /// A fixed color wins over the item's own, which is how the watch and widget lists stay on tint.
    @Test func rowPrefersTheGivenIconColorOverTheItemCustomization() {
        assertLightDarkSnapshots(
            of: List {
                MagicItemConfigurationRow(
                    item: .init(
                        id: "light.kitchen",
                        serverId: "1",
                        type: .entity,
                        customization: .init(iconColor: "#FF0000")
                    ),
                    info: .init(id: "1-light.kitchen", name: "Kitchen light", iconName: "mdi:lightbulb"),
                    iconColor: .haPrimary,
                    isReorderIndicatorVisible: false
                )
            },
            drawHierarchyInKeyWindow: true
        )
    }

    private func list(isReorderIndicatorVisible: Bool) -> some View {
        List {
            MagicItemConfigurationRow(
                item: .init(id: "light.kitchen", serverId: "1", type: .entity, customization: .init()),
                info: .init(
                    id: "1-light.kitchen",
                    name: "Kitchen light",
                    iconName: "mdi:lightbulb",
                    contextSubtitle: "Home • Kitchen"
                ),
                isReorderIndicatorVisible: isReorderIndicatorVisible
            )
            MagicItemConfigurationRow(
                item: .init(
                    id: "script.morning",
                    serverId: "1",
                    type: .script,
                    customization: .init(iconColor: "#FF9800")
                ),
                info: .init(id: "1-script.morning", name: "Morning routine", iconName: "mdi:script-text"),
                isReorderIndicatorVisible: isReorderIndicatorVisible
            )
        }
    }
}
