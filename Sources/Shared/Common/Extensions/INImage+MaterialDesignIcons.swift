import Foundation
import Intents

public extension INImage {
    #if os(iOS) || os(macOS)
    convenience init(
        icon: MaterialDesignIcons,
        foreground: UIColor,
        background: UIColor
    ) {
        MaterialDesignIcons.register()

        let iconRect = CGRect(x: 0, y: 0, width: 64, height: 64)

        #if os(macOS)
        let renderer = UIGraphicsImageRenderer(size: iconRect.size)
        #else
        let renderer = UIKit.UIGraphicsImageRenderer(size: iconRect.size)
        #endif

        let iconData = renderer.pngData { _ in
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
