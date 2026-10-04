@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the pill list out in a hosting controller, which is what makes SwiftUI evaluate its body.
@MainActor
struct ServersPickerPillListTests {
    private func fittingSize(of view: some View) -> CGSize {
        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        return controller.sizeThatFits(in: CGSize(width: 390, height: 844))
    }

    private func makeServers() -> [Server] {
        [
            Server.fake(identifier: "first", update: { info in
                info.remoteName = "First"
                info.sortOrder = 2
            }),
            Server.fake(identifier: "second", update: { info in
                info.remoteName = "Second"
                info.sortOrder = 1
            }),
            Server.fake(identifier: "third", update: { info in
                info.remoteName = "Third"
                info.sortOrder = 3
            }),
        ]
    }

    @Test func showsPillsOnlyWhenThereIsMoreThanOneServer() {
        let servers = makeServers()

        let multipleServersSize = fittingSize(of: ServersPickerPillList(
            servers: servers,
            selectedServerId: .constant("second")
        ))
        let singleServerSize = fittingSize(of: ServersPickerPillList(
            servers: [servers[0]],
            selectedServerId: .constant("first")
        ))

        #expect(multipleServersSize.height > 0)
        #expect(multipleServersSize.height > singleServerSize.height)
    }

    @Test func rendersInsideAListWithoutASelection() {
        let size = fittingSize(of: List {
            ServersPickerPillList(servers: makeServers(), selectedServerId: .constant(nil))
            Text("Content")
        })

        #expect(size.width > 0)
    }
}
