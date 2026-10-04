@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the folder editor out with and without custom colors, and with and without a saved icon, so
/// SwiftUI evaluates both sections and the color pickers that only appear with custom colors on.
@MainActor
struct FolderEditViewRenderTests {
    @Test func rendersAFolderWithCustomColorsAndIcon() {
        let folder = MagicItem(
            id: "folder-1",
            serverId: "",
            type: .folder,
            customization: .init(
                iconColor: "#FF0000",
                textColor: "#FFFFFF",
                backgroundColor: "#000000",
                icon: "lightbulb"
            ),
            displayText: "Lights",
            items: []
        )
        var saved: MagicItem?
        #expect(render(NavigationView { FolderEditView(folder: folder) { saved = $0 } }))
        #expect(saved == nil)
    }

    @Test func rendersAPlainFolderOutsideTheWatchAppearance() {
        let folder = MagicItem(id: "folder-2", serverId: "", type: .folder, customization: nil, items: [])
        #expect(render(NavigationView {
            FolderEditView(folder: folder, usesDarkColorScheme: false) { _ in }
        }))
    }

    /// Deliberately never becomes the key window, so it can't leak into snapshot tests. Returns
    /// whether the hosted view was laid out in the window.
    private func render(_ view: some View) -> Bool {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        let laidOut = controller.view.window === window

        window.isHidden = true
        window.rootViewController = nil
        return laidOut
    }
}
