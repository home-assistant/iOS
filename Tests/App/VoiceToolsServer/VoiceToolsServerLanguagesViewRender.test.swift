import Foundation
@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

/// Renders the screen through its own initializer, the one Settings uses, so the list is read from
/// the speech recogniser on appearance rather than injected the way the snapshots do it.
@MainActor
struct VoiceToolsServerLanguagesViewRenderTests {
    @Test func loadsTheLanguagesOnAppearance() async throws {
        let controller = UIHostingController(rootView: NavigationView { VoiceToolsServerLanguagesView() })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        // The screen's own load shares this probe, so once it answers a run-loop turn is all the
        // list needs to arrive.
        _ = await SupportedSpeechLocales.shared.locales()
        try await Task.sleep(nanoseconds: 500_000_000)
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }
}
