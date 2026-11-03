@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// The manual server address page: rendered empty, with an address that gets the http/https helper
/// buttons, and with one that already carries a scheme.
@MainActor
struct ManualURLEntryViewTests {
    @Test(arguments: ["", "homeassistant.local:8123", "https://homeassistant.local:8123", "ha"])
    func rendersForEachKindOfAddress(initialURL: String) async {
        var connected: [URL] = []
        let controller =
            UIHostingController(rootView: ManualURLEntryView(initialURL: initialURL) { connected.append($0) })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()
        for _ in 0 ..< 3 {
            await Task.yield()
        }
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.isHidden = true
        window.rootViewController = nil

        // Nothing connects until the person taps Connect.
        #expect(connected.isEmpty)
    }
}
