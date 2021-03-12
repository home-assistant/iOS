#if os(iOS)
import UIKit

public extension UIBarButtonItem {
    convenience init(icon: MaterialDesignIcons, target: Any?, action: Selector?) {
        self.init(
            image: icon.image(ofSize: CGSize(width: 28, height: 28), color: nil),
            landscapeImagePhone: icon.image(ofSize: CGSize(width: 20, height: 20), color: nil),
            style: .plain,
            target: target,
            action: action
        )
        accessibilityLabel = icon.name
    }
}
#endif
