import UIKit
import Shared

class AppMacBridgeStatusItemConfiguration: MacBridgeStatusItemConfiguration {
    init(
        isVisible: Bool,
        image: CGImage,
        imageSize: CGSize,
        accessibilityLabel: String,
        primaryActionHandler: @escaping (MacBridgeStatusItemCallbackInfo) -> Void
    ) {
        self.isVisible = isVisible
        self.image = image
        self.imageSize = imageSize
        self.accessibilityLabel = accessibilityLabel
        self.primaryActionHandler = primaryActionHandler
    }

    var isVisible: Bool
    var image: CGImage
    var imageSize: CGSize
    var accessibilityLabel: String
    var primaryActionHandler: (MacBridgeStatusItemCallbackInfo) -> Void
}
