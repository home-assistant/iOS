@testable import HomeAssistant
@testable import Shared
import Testing

struct ActiveEntitiesFinderTests {
    private func state(name: String) -> HAEntityStateAppEntity {
        var state = HAEntityStateAppEntity()
        state.name = name
        return state
    }

    @Test func namesEverythingThatIsOn() {
        let dialog = ActiveEntitiesFinder.dialog(
            for: [state(name: "Kitchen"), state(name: "Hall")],
            filter: .light
        )
        #expect(dialog == "These lights are on: Kitchen and Hall")
    }

    @Test func saysNothingIsOnWhenTheListIsEmpty() {
        #expect(ActiveEntitiesFinder.dialog(for: [], filter: .light) == "No lights are on")
    }

    @Test func coversReadAsOpenRatherThanOn() {
        #expect(ActiveEntitiesFinder.dialog(for: [], filter: .cover) == "No covers are open")
        #expect(
            ActiveEntitiesFinder.dialog(for: [state(name: "Blinds")], filter: .cover)
                == "These covers are open: Blinds"
        )
    }

    @Test func everyFilterResolvesDomainsAndADisplayName() {
        for filter in ActiveEntitiesFilterAppEnum.allCases {
            #expect(!filter.domains.isEmpty, "\(filter.rawValue) resolves no domains")
            #expect(!filter.localizedPluralName.isEmpty, "\(filter.rawValue) has no display name")
        }
    }
}
