@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing

struct RestoredRegistrationsNextServerViewTests {
    /// The hand-off between two servers, rendered at a sheet's height like the screen it is shown over.
    @MainActor @Test func handOffSnapshot() async throws {
        guard #available(iOS 18.0, *) else { return }

        let home = Server.fake(identifier: "home", initial: with(ServerInfo.fake()) { $0.remoteName = "Home" })
        let cabin = Server.fake(identifier: "cabin", initial: with(ServerInfo.fake()) { $0.remoteName = "Cabin" })

        assertLightDarkSnapshots(
            of: AnyView(RestoredRegistrationsNextServerView(next: .init(
                previous: home,
                previousState: .done,
                next: cabin,
                position: 2,
                count: 3,
                goOn: {}
            ))),
            layout: .fixed(width: 390, height: 640),
            named: "restored-registrations-next-server"
        )
    }
}
