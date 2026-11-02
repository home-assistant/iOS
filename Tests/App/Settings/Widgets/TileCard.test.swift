@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

/// The widget builder's tile preview, with and without its second line.
@MainActor
struct TileCardTests {
    @Test func rendersWithAndWithoutASubtitle() {
        let view = VStack {
            TileCard(content: .init(title: "Kitchen", subtitle: "On", image: Image(systemName: "lightbulb")))
            TileCard(content: .init(title: "Porch", subtitle: nil, image: Image(systemName: "lightbulb")))
        }
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 200))
        window.rootViewController = controller
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        controller.view.layoutIfNeeded()
        #expect(controller.view.bounds.width == 390)
    }
}
