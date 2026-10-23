@testable import HomeAssistant
import Shared
import Testing

struct HomeAssistantStandByViewConnectionToastTests {
    @MainActor @Test func remoteUIToastNamesHomeAssistantLink() {
        let server = HomeAssistantStandByView.previewServer(
            name: "Link Server",
            configuredURLTypes: [.remoteUI],
            activeURLType: .remoteUI
        )
        let view = HomeAssistantStandByView(server: server, emptyState: nil)

        #expect(view.connectionTypeToastMessage == "Using Home Assistant Link Remote UI URL.")
    }
}
