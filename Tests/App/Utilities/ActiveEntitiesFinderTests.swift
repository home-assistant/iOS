@testable import HomeAssistant
@testable import Shared
import Testing

struct ActiveEntitiesFinderTests {
    private func state(name: String, serverName: String = "") -> HAEntityStateAppEntity {
        var state = HAEntityStateAppEntity()
        state.name = name
        state.serverName = serverName
        return state
    }

    /// Points `Current` at `count` fake servers for the duration of the body.
    private func withServers(_ count: Int, _ body: () throws -> Void) rethrows {
        let previous = Current.servers
        defer { Current.servers = previous }
        Current.servers = FakeServerManager(initial: count)
        try body()
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

    @Test func namesTheServerOnlyWhenThereIsMoreThanOne() throws {
        let entity = state(name: "Kitchen", serverName: "Cabin")

        try withServers(1) {
            #expect(ActiveEntitiesFinder.spokenName(for: entity) == "Kitchen")
        }
        try withServers(2) {
            #expect(ActiveEntitiesFinder.spokenName(for: entity) == "Kitchen on Cabin")
        }
    }
}
