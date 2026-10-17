import Foundation
import HAKit
@testable import HomeAssistant
import Testing

struct FrontendDefaultPanelDataTests {
    @Test("Decodes the default panel from the core user data envelope")
    func decoding() throws {
        let data = try FrontendDefaultPanelData(data: HAData(value: [
            "value": ["default_panel": "energy", "showEntityIdPicker": true],
        ]))
        #expect(data.defaultPanel == "energy")

        let empty = try FrontendDefaultPanelData(data: HAData(value: ["value": NSNull()]))
        #expect(empty.defaultPanel == nil)
    }
}
