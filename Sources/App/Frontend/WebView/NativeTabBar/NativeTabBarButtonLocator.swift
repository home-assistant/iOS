import UIKit

/// Finds where the tab bar draws a tab, in window coordinates, so a presentation can zoom out of it.
enum NativeTabBarButtonLocator {
    static func tabBar(in window: UIWindow) -> UITabBar? {
        firstView(in: window, where: { $0 is UITabBar }) as? UITabBar
    }

    static func frame(ofButtonTitled title: String, trailing: Bool, in window: UIWindow? = keyWindow) -> CGRect? {
        guard let window, let tabBar = tabBar(in: window) else { return nil }
        let button = firstView(in: tabBar, where: { ($0 as? UILabel)?.text == title }).map(control(enclosing:))
            ?? (trailing ? trailingControl(in: tabBar) : nil)
        guard let button else { return nil }
        return button.convert(button.bounds, to: window)
    }

    static var keyWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
    }

    private static func control(enclosing view: UIView) -> UIView {
        var candidate: UIView? = view
        for _ in 0 ..< 4 {
            if let control = candidate, control is UIControl {
                return control
            }
            candidate = candidate?.superview
        }
        return view.superview?.superview ?? view
    }

    private static func trailingControl(in tabBar: UIView) -> UIView? {
        var controls: [UIView] = []
        collectViews(in: tabBar, where: { $0 is UIControl && $0.bounds.width > 0 }, into: &controls)
        return controls.max { lhs, rhs in
            lhs.convert(lhs.bounds, to: tabBar).maxX < rhs.convert(rhs.bounds, to: tabBar).maxX
        }
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

    private static func collectViews(in root: UIView, where predicate: (UIView) -> Bool, into result: inout [UIView]) {
        for subview in root.subviews {
            if predicate(subview) {
                result.append(subview)
            }
            collectViews(in: subview, where: predicate, into: &result)
        }
    }
}
