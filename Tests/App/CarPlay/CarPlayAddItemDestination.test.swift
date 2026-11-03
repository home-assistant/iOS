@testable import HomeAssistant
import Testing

/// Each Quick Access item type maps to the picker the add sheet opens; an Assist prompt has its own
/// editor instead of a picker.
struct CarPlayAddItemDestinationTests {
    @Test func eachDestinationMapsToItsPicker() {
        #expect(CarPlayAddItemDestination.entity.id == "entity")
        #expect(CarPlayAddItemDestination.entity.magicItemType == .entities)
        #expect(CarPlayAddItemDestination.entity.pickerOption == .entities)
        #expect(CarPlayAddItemDestination.assist.magicItemType == .assistPipelines)
        #expect(CarPlayAddItemDestination.assist.pickerOption == .assistPipelines)
        #expect(CarPlayAddItemDestination.assistPrompt.magicItemType == nil)
        #expect(CarPlayAddItemDestination.assistPrompt.pickerOption == nil)
    }
}
