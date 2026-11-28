@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

@MainActor
struct LaunchSplashOverlayViewRenderTests {
    @Test func theSplashKeepsWaitingForADestinationLogoWhileItLaysOut() {
        let state = LaunchSplashOverlayState()
        let controller = UIHostingController(rootView: LaunchSplashOverlayView(state: state))
        controller.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 84)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        #expect(state.phase == .waiting)
    }
}
