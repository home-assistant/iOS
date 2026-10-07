import Foundation
import HAKit
@testable import HomeAssistant
import Testing

struct PersistentNotificationsMessageTests {
    @Test("Snapshots replace, changes merge, removals subtract")
    func applyChanges() throws {
        let current = try PersistentNotificationsMessage(data: .dictionary([
            "type": "current",
            "notifications": ["a": [:], "b": [:]],
        ]))
        var ids = current.apply(to: ["stale"])
        #expect(ids == ["a", "b"])

        let added = try PersistentNotificationsMessage(data: .dictionary([
            "type": "added",
            "notifications": ["c": [:]],
        ]))
        ids = added.apply(to: ids)
        #expect(ids == ["a", "b", "c"])

        let removed = try PersistentNotificationsMessage(data: .dictionary([
            "type": "removed",
            "notifications": ["a": [:]],
        ]))
        ids = removed.apply(to: ids)
        #expect(ids == ["b", "c"])
    }

    @Test("Unknown change types fail to decode")
    func unknownType() {
        #expect(throws: (any Error).self) {
            try PersistentNotificationsMessage(data: .dictionary(["type": "bogus", "notifications": [:]]))
        }
    }

    @Test("Sidebar user data decodes its envelope and tolerates a null value")
    func sidebarUserData() throws {
        let data = try FrontendSidebarUserData(data: .dictionary([
            "value": ["panelOrder": ["map", "energy"], "hiddenPanels": ["logbook"]],
        ]))
        #expect(data.panelOrder == ["map", "energy"])
        #expect(data.hiddenPanels == ["logbook"])

        let empty = try FrontendSidebarUserData(data: .dictionary(["value": NSNull()]))
        #expect(empty == FrontendSidebarUserData())
        #expect(empty.panelOrder == nil)

        let core = try FrontendDefaultPanelData(data: .dictionary(["value": ["default_panel": "map"]]))
        #expect(core.defaultPanel == "map")
    }
}
