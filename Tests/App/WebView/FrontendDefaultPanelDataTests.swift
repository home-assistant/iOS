import HAKit
@testable import HomeAssistant
import Testing

struct FrontendDefaultPanelDataTests {
    @Test("Decodes the default panel from the core user data envelope and keeps the other keys")
    func decoding() throws {
        let data = try FrontendDefaultPanelData(data: HAData(value: [
            "value": ["default_panel": "energy", "showEntityIdPicker": true],
        ]))
        #expect(data.defaultPanel == "energy")
        #expect(data.rawValue["showEntityIdPicker"] as? Bool == true)

        let empty = try FrontendDefaultPanelData(data: HAData(value: ["value": NSNull()]))
        #expect(empty.defaultPanel == nil)
        #expect(empty.rawValue.isEmpty)
    }

    @Test("Setting the default dashboard merges into the existing core value like the frontend does")
    func settingDefault() throws {
        let data = try FrontendDefaultPanelData(data: HAData(value: [
            "value": ["default_panel": "energy", "showEntityIdPicker": true],
        ]))
        let updated = data.settingDefaultPanel("map")
        #expect(updated.defaultPanel == "map")
        #expect(updated.rawValue["default_panel"] as? String == "map")
        #expect(updated.rawValue["showEntityIdPicker"] as? Bool == true)
    }
}
