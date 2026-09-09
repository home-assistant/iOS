import UIKit

/// Finds where the tab bar draws a tab, in window coordinates, so a presentation can zoom out of it.
enum NativeTabBarButtonLocator {
    static func frame(ofButtonTitled title: String, in window: UIWindow? = keyWindow) -> CGRect? {
        guard let window, let tabBar = firstView(ofType: UITabBar.self, in: window) else { return nil }
        guard let button = firstView(in: tabBar, where: { $0.accessibilityLabel == title }) else { return nil }
        return button.convert(button.bounds, to: window)
    }

    static var keyWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
    }

    private static func firstView<View: UIView>(ofType type: View.Type, in root: UIView) -> View? {
        firstView(in: root, where: { $0 is View }) as? View
    }

    private static func firstView(in root: UIView, where predicate: (UIView) -> Bool) -> UIView? {
        for subview in root.subviews {
            if predicate(subview) {
                return subview
            }
            if let match = firstView(in: subview, where: predicate) {
                return match
            }
        }
        return nil
    }
}
