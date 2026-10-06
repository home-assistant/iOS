@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

struct OnboardingAuthLoginViewTests {
    /// The web view is laid out edge to edge, so a horizontal safe area inset (iPhone Duo camera
    /// or vertical bar) must not narrow it; WebKit insets the page content itself.
    @MainActor @Test func webViewSpansTheWholeWidthPastTheSafeArea() throws {
        let viewModel = OnboardingAuthLoginViewModel(
            authDetails: try OnboardingAuthDetails(baseURL: URL(string: "http://homeassistant.local:8123")!)
        )
        let controller = UIHostingController(rootView: OnboardingAuthLoginView(viewModel: viewModel))
        controller.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 80)
        // The representable only reaches the hierarchy inside a window.
        let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: 390, height: 844)))
        window.rootViewController = controller
        window.makeKeyAndVisible()

        window.layoutIfNeeded()

        let webViewWidth = viewModel.webView.frame.width
        #expect(webViewWidth == 390, "web view width \(webViewWidth) should fill the window, ignoring the 80pt inset")
        window.isHidden = true
    }
}
