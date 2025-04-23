@testable import HomeAssistant
import Testing

struct WKUserContentControllerMessageTests {
    @Test func testWKUserContentControllerMessageCases() async throws {
        // Assert the total count of cases
        assert(WKUserContentControllerMessage.allCases.count == 5)

        // Assert each case's rawValue
        assert(WKUserContentControllerMessage.externalBus.rawValue == "externalBus")
        assert(WKUserContentControllerMessage.updateThemeColors.rawValue == "updateThemeColors")
        assert(WKUserContentControllerMessage.getExternalAuth.rawValue == "getExternalAuth")
        assert(WKUserContentControllerMessage.revokeExternalAuth.rawValue == "revokeExternalAuth")
        assert(WKUserContentControllerMessage.logError.rawValue == "logError")
    }
}
