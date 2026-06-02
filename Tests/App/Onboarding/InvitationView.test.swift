@testable import HomeAssistant
import Shared
import SnapshotTesting
import SwiftUI
import Testing

struct InvitationViewTests {
    @MainActor @Test func invitationSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }

        let view = NavigationView {
            InvitationView(
                invitationURL: URL(string: "http://192.168.0.188:8123")!,
                isAccepting: false,
                onAccept: {},
                onReject: {}
            )
        }
        .navigationViewStyle(.stack)

        assertLightDarkSnapshots(of: view, named: "invitation")
    }
}
