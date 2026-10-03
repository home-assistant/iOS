import Foundation
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Lays out the picker in each of its modes so the search field and the list are built.
// Serialized: the tests swap `Current.servers`, which concurrent tests would race on.
@MainActor
@Suite(.serialized)
struct EntityPickerRenderTests {
    @Test func rendersEveryMode() {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 1)

        for mode in [EntityPicker.Mode.button, .list, .inline] {
            renderInWindow(NavigationView {
                EntityPicker(selectedEntity: .constant(nil), domainFilter: nil, mode: mode)
            })
        }
    }
}
