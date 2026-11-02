@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// The server pill picker renders only when there is more than one server to choose from.
@MainActor
struct ServersPickerPillListTests {
    private final class Selection {
        var serverId: String?
    }

    private func render(_ servers: [Server], selection: Selection) -> UIView {
        let binding = Binding<String?>(get: { selection.serverId }, set: { selection.serverId = $0 })
        let controller = UIHostingController(rootView: List {
            ServersPickerPillList(servers: servers, selectedServerId: binding)
        })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        return controller.view
    }

    @Test func rendersPillsForSeveralServers() {
        let manager = FakeServerManager(initial: 3)
        let selection = Selection()
        selection.serverId = manager.all[1].identifier.rawValue
        _ = render(manager.all, selection: selection)
        #expect(selection.serverId == manager.all[1].identifier.rawValue)
    }

    @Test func rendersNothingForASingleServer() {
        let manager = FakeServerManager(initial: 1)
        _ = render(manager.all, selection: Selection())
        _ = render([], selection: Selection())
        #expect(manager.all.count == 1)
    }
}
