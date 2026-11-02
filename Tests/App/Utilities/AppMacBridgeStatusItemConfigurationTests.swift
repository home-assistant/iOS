@testable import HomeAssistant
@testable import Shared
import Testing
import UIKit

/// The status item configuration handed to the Mac bridge: menu items combine their modifier keys
/// into a mask, expose their image, and separators carry nothing else.
struct AppMacBridgeStatusItemConfigurationTests {
    @Test func menuItemsDescribeThemselvesToTheBridge() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { _ in }
        let child = AppMacBridgeStatusItemMenuItem(name: "Child")
        var activated = 0
        let item = AppMacBridgeStatusItemMenuItem(
            name: "Preferences",
            image: image,
            keyEquivalentModifier: [.command, .shift],
            keyEquivalent: ",",
            subitems: [child],
            primaryActionHandler: { _ in activated += 1 }
        )

        #expect(item.name == "Preferences")
        #expect(item.image != nil)
        #expect(item.imageSize == image.size)
        #expect(
            item.keyEquivalentModifierMask == MacBridgeStatusModifierMask.command.rawValue
                | MacBridgeStatusModifierMask.shift.rawValue
        )
        #expect(item.keyEquivalent == ",")
        #expect(item.subitems.count == 1)
        #expect(!item.isSeparator)

        let separator = AppMacBridgeStatusItemMenuItem.separator()
        #expect(separator.isSeparator)
        #expect(separator.name.isEmpty)
        #expect(separator.image == nil)
        #expect(separator.imageSize == .zero)
        #expect(separator.keyEquivalent.isEmpty)
        #expect(activated == 0)
    }

    @Test func theConfigurationKeepsWhatItWasGiven() {
        let configuration = AppMacBridgeStatusItemConfiguration(
            isVisible: true,
            imageName: "statusItemIcon",
            imageBundle: .main,
            accessibilityLabel: "Home Assistant",
            items: [AppMacBridgeStatusItemMenuItem(name: "Toggle")],
            primaryActionHandler: { _ in }
        )
        #expect(configuration.isVisible)
        #expect(configuration.imageName == "statusItemIcon")
        #expect(configuration.imageBundle == .main)
        #expect(configuration.accessibilityLabel == "Home Assistant")
        #expect(configuration.items.count == 1)
    }
}
