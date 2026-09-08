import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Renders the screen the way the settings list builds it — through its own initializer, against
/// the real stored settings — rather than the injected one the snapshots use. That path is what
/// ships, and nothing else exercises it.
@MainActor
@Suite(.serialized)
struct VoiceToolsServerSettingsViewRenderTests {
    private func withTestDatabase(seeding configuration: VoiceToolsServerConfiguration?, _ work: () -> Void) throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let previousDatabase = Current.database
        Current.database = { database }
        defer { Current.database = previousDatabase }

        configuration?.save()
        work()
    }

    /// Lays the view out in a window, which is what makes SwiftUI evaluate the body and run
    /// `onAppear`.
    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    @Test func rendersWithTheServerOff() throws {
        try withTestDatabase(seeding: nil) {
            render(NavigationView { VoiceToolsServerSettingsView() })
        }
    }

    /// With the server on, the status and port rows render too, and the port field seeds itself
    /// from the stored settings.
    @Test func rendersTheStatusAndPortRowsWhenOn() throws {
        try withTestDatabase(seeding: .init(isEnabled: true, port: 10805)) {
            render(NavigationView { VoiceToolsServerSettingsView() })
        }
    }
}
