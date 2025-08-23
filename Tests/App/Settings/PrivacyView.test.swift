@testable import HomeAssistant
import Testing

struct PrivacyViewTests {
    @MainActor
    @Test func testUI() async throws {
        assertLightDarkSnapshots(of: PrivacyView())
    }
}
