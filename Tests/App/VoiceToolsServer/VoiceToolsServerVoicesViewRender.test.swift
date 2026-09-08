import Foundation
@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

/// Renders the screen through its own initializer, the one Settings uses, so the voices are read
/// from the TextToSpeech daemon on appearance rather than injected the way the snapshots do it.
@MainActor
struct VoiceToolsServerVoicesViewRenderTests {
    @Test func loadsTheVoicesOnAppearance() async throws {
        let controller = UIHostingController(rootView: NavigationView { VoiceToolsServerVoicesView() })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        // The screen's own load waits on the same daemon, so once this answers a run-loop turn is
        // all the list needs to arrive.
        _ = await OnDeviceVoiceCatalog.voices()
        try await Task.sleep(nanoseconds: 500_000_000)
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }
}
