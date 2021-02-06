import Foundation
import Intents

public extension INImage {
    #if os(iOS)
    convenience init(
        icon: MaterialDesignIcons,
        foreground: UIColor,
        background: UIColor
    ) {
        MaterialDesignIcons.register()

        let iconRect = CGRect(x: 0, y: 0, width: 64, height: 64)

        let iconData = UIKit.UIGraphicsImageRenderer(size: iconRect.size).pngData { _ in
            let imageRect = iconRect.insetBy(dx: 8, dy: 8)

            background.set()
            UIRectFill(iconRect)

            icon
                .image(ofSize: imageRect.size, color: foreground)
                .draw(in: imageRect)
        }

        self.init(imageData: iconData)
    }
    #endif
}
