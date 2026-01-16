import SwiftUI

/// A specialized UIHostingController for displaying dynamic island toasts.
///
/// This controller extends UIHostingController to provide dynamic status bar visibility control.
/// When a toast is presented, the status bar can be hidden to create a cleaner, more immersive
/// animation effect as the toast expands from the dynamic island area.
///
/// The status bar visibility is controlled through the `isStatusBarHidden` property, which
/// automatically triggers a status bar appearance update when changed.
@available(iOS 18, *)
public class ToastHostingController: UIHostingController<ToastView> {
    /// Controls whether the status bar should be hidden.
    ///
    /// When set to `true`, the status bar is hidden to avoid visual conflicts with the toast animation.
    /// When set to `false`, the status bar is shown again after the toast is dismissed.
    public var isStatusBarHidden: Bool = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    /// Indicates whether the status bar should be hidden.
    ///
    /// This property is queried by UIKit to determine status bar visibility.
    override public var prefersStatusBarHidden: Bool {
        isStatusBarHidden
    }
}
