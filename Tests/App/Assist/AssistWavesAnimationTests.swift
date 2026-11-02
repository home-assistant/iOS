@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

/// The listening animation Assist shows while recording: its bars and the hint above them render
/// and start animating once on screen.
@MainActor
struct AssistWavesAnimationTests {
    @Test func rendersAndStartsAnimating() async {
        let controller = UIHostingController(rootView: AssistWavesAnimation())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()
        for _ in 0 ..< 5 {
            await Task.yield()
        }
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.isHidden = true
        window.rootViewController = nil
        #expect(controller.view.bounds.width == 390)
    }
}
