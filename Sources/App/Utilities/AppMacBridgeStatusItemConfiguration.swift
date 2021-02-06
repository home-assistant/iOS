import Shared
import UIKit

class AppMacBridgeStatusItemConfiguration: MacBridgeStatusItemConfiguration {
    init(
        isVisible: Bool,
        image: CGImage,
        imageSize: CGSize,
        accessibilityLabel: String,
        items: [MacBridgeStatusItemMenuItem],
        primaryActionHandler: @escaping (MacBridgeStatusItemCallbackInfo) -> Void
    ) {
        self.isVisible = isVisible
        self.image = image
        self.imageSize = imageSize
        self.accessibilityLabel = accessibilityLabel
        self.items = items
        self.primaryActionHandler = primaryActionHandler
    }

    var isVisible: Bool
    var image: CGImage
    var imageSize: CGSize
    var accessibilityLabel: String
    var items: [MacBridgeStatusItemMenuItem]
    var primaryActionHandler: (MacBridgeStatusItemCallbackInfo) -> Void
}

final class AppMacBridgeStatusItemMenuItem: MacBridgeStatusItemMenuItem {
    class func separator() -> Self {
        .init(isSeparator: true)
    }

    init(
        name: String? = nil,
        image: UIImage? = nil,
        isSeparator: Bool = false,
        keyEquivalentModifier: [MacBridgeStatusModifierMask] = [],
        keyEquivalent: String? = nil,
        subitems: [MacBridgeStatusItemMenuItem] = [],
        primaryActionHandler: @escaping (MacBridgeStatusItemCallbackInfo) -> Void = { _ in }
    ) {
        self.name = name ?? ""
        self.backingImage = image
        self.isSeparator = isSeparator
        self.keyEquivalentModifierMask = keyEquivalentModifier.reduce(into: Int(0)) { val, new in
            val |= new.rawValue
        }
        self.keyEquivalent = keyEquivalent ?? ""
        self.subitems = subitems
        self.primaryActionHandler = primaryActionHandler
    }

    var backingImage: UIImage?
    var name: String
    var image: CGImage? {
        if let image = backingImage {
            return image.cgImage!
        } else {
            return nil
        }
    }

    var imageSize: CGSize {
        backingImage?.size ?? .zero
    }

    var isSeparator: Bool
    var keyEquivalentModifierMask: Int
    var keyEquivalent: String
    var subitems: [MacBridgeStatusItemMenuItem]
    var primaryActionHandler: (MacBridgeStatusItemCallbackInfo) -> Void
}
