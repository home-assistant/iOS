@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Lays the pills out for two servers, which is when the list shows at all.
@MainActor
struct ServersPickerPillListRenderTests {
    @Test func rendersAPillPerServer() {
        let servers = [Server.fake(), Server.fake()]
        renderInWindow(List {
            ServersPickerPillList(servers: servers, selectedServerId: .constant(servers[0].identifier.rawValue))
        }, height: 300)
    }
}
