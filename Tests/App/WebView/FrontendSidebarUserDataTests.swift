@testable import HomeAssistant
import Testing

struct FrontendSidebarUserDataTests {
    @Test("Hiding removes the panel from the order and appends it to hidden, seeding the order on first edit")
    func hiding() {
        let userData = FrontendSidebarUserData().hiding("energy", visibleOrder: ["home", "energy", "map"])
        #expect(userData.panelOrder == ["home", "map"])
        #expect(userData.hiddenPanels == ["energy"])

        let again = userData.hiding("energy", visibleOrder: ["home", "map"])
        #expect(again.hiddenPanels == ["energy"])
    }

    @Test("Showing removes the panel from hidden and appends it to the order")
    func showing() {
        let userData = FrontendSidebarUserData(panelOrder: ["home"], hiddenPanels: ["energy", "map"])
            .showing("map", visibleOrder: ["home"])
        #expect(userData.panelOrder == ["home", "map"])
        #expect(userData.hiddenPanels == ["energy"])
    }

    @Test("Reordering replaces the order and keeps hidden panels")
    func reordering() {
        let userData = FrontendSidebarUserData(panelOrder: ["a", "b"], hiddenPanels: ["c"]).reordered(to: ["b", "a"])
        #expect(userData.panelOrder == ["b", "a"])
        #expect(userData.hiddenPanels == ["c"])
    }

    @Test("Encoding matches the frontend's user data shape; defaults encode as an empty object")
    func encoding() {
        let encoded = FrontendSidebarUserData(panelOrder: ["a"], hiddenPanels: ["b"]).encoded
        #expect(encoded["panelOrder"] as? [String] == ["a"])
        #expect(encoded["hiddenPanels"] as? [String] == ["b"])
        #expect(FrontendSidebarUserData().encoded.isEmpty)
        #expect(!FrontendSidebarUserData().isCustomised)
    }
}
