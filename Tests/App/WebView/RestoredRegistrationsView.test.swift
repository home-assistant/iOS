@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing

struct RestoredRegistrationsViewTests {
    /// The prompt is sheet content, so it is rendered at a sheet's height rather than full screen.
    @MainActor @Test func promptSnapshot() async throws {
        guard #available(iOS 18.0, *) else { return }

        let servers = [
            Server.fake(identifier: "home", initial: with(ServerInfo.fake()) { $0.remoteName = "Home" }),
            Server.fake(identifier: "cabin", initial: with(ServerInfo.fake()) { $0.remoteName = "Cabin" }),
        ]

        let viewModel = RestoredRegistrationsViewModel(servers: servers, onFinished: {})

        assertLightDarkSnapshots(
            of: AnyView(RestoredRegistrationsView(viewModel: viewModel)),
            layout: .fixed(width: 390, height: 640),
            named: "restored-registrations-sheet"
        )
    }

    /// With many servers the rows scroll while the choices stay put, and a running count says how far along it is.
    @MainActor @Test func manyServersSnapshot() async throws {
        guard #available(iOS 18.0, *) else { return }

        let servers = (1 ... 30).map { number in
            Server.fake(identifier: .init(rawValue: "server-\(number)"), initial: with(ServerInfo.fake()) {
                $0.remoteName = "Server \(number)"
            })
        }
        let viewModel = RestoredRegistrationsViewModel(servers: servers, onFinished: {})

        assertLightDarkSnapshots(
            of: AnyView(RestoredRegistrationsView(viewModel: viewModel)),
            layout: .fixed(width: 390, height: 640),
            named: "restored-registrations-sheet-many"
        )
        assertLightDarkSnapshots(
            of: AnyView(RestoredRegistrationsView(viewModel: viewModel)),
            layout: .fixed(width: 390, height: 2200),
            named: "restored-registrations-sheet-many-tall"
        )
    }
}
