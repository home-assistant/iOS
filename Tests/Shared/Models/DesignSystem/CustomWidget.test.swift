import Foundation
@testable import Shared
import Testing

struct CustomWidgetTests {
    @Test func startsWithoutItemStates() {
        let widget = CustomWidget(id: "widget", name: "Kitchen", items: [])

        #expect(widget.id == "widget")
        #expect(widget.name == "Kitchen")
        #expect(widget.items.isEmpty)
        #expect(widget.itemsStates.isEmpty)
    }

    @Test func updatingItemStatesReplacesThePreviousOnes() {
        var widget = CustomWidget(
            id: "widget",
            name: "Kitchen",
            items: [],
            itemsStates: ["1-light.kitchen": .pendingConfirmation]
        )

        widget.updateItemsStates(["1-lock.front_door": .pendingTapConfirmation])

        #expect(widget.itemsStates == ["1-lock.front_door": .pendingTapConfirmation])
    }

    @Test func pendingConfirmationCoversBothPendingStates() {
        #expect(!CustomWidget.ItemState.idle.isPendingConfirmation)
        #expect(CustomWidget.ItemState.pendingConfirmation.isPendingConfirmation)
        #expect(CustomWidget.ItemState.pendingTapConfirmation.isPendingConfirmation)
    }

    @Test func roundTripsThroughJSON() throws {
        let widget = CustomWidget(
            id: "widget",
            name: "Kitchen",
            items: [MagicItem(id: "light.kitchen", serverId: "1", type: .entity)],
            itemsStates: ["1-light.kitchen": .pendingConfirmation]
        )

        let data = try JSONEncoder().encode(widget)
        let decoded = try JSONDecoder().decode(CustomWidget.self, from: data)

        #expect(decoded == widget)
    }
}
