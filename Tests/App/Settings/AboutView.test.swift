@testable import HomeAssistant
import Testing

struct AboutViewTests {
    @MainActor
    @Test func testUI() async throws {
        assertLightDarkSnapshots(of: AboutView())
    }
}
