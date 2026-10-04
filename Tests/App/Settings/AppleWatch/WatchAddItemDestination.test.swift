@testable import HomeAssistant
import Testing

/// Each add-menu entry opens the matching picker; the Assist prompt is built in its own editor, so it
/// has no picker of its own.
struct WatchAddItemDestinationTests {
    @Test func pickerDestinationsMapToTheirPickers() {
        #expect(WatchAddItemDestination.entity.magicItemType == .entities)
        #expect(WatchAddItemDestination.area.magicItemType == .areas)
        #expect(WatchAddItemDestination.complication.magicItemType == .complications)
        #expect(WatchAddItemDestination.assist.magicItemType == .assistPipelines)

        #expect(WatchAddItemDestination.entity.pickerOption == .entities)
        #expect(WatchAddItemDestination.area.pickerOption == .areas)
        #expect(WatchAddItemDestination.complication.pickerOption == .complications)
        #expect(WatchAddItemDestination.assist.pickerOption == .assistPipelines)
    }

    @Test func assistPromptHasNoPicker() {
        #expect(WatchAddItemDestination.assistPrompt.magicItemType == nil)
        #expect(WatchAddItemDestination.assistPrompt.pickerOption == nil)
    }

    @Test func identifiersAreTheRawValues() {
        let destinations: [WatchAddItemDestination] = [.entity, .area, .complication, .assist, .assistPrompt]
        #expect(destinations.map(\.id) == ["entity", "area", "complication", "assist", "assistPrompt"])
    }
}
