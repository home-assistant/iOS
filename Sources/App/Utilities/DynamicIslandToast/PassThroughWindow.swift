import SwiftUI

@available(iOS 18, *)
@Observable
/// Custom UIWindow that passes through touches in transparent/non-interactive areas
class PassThroughWindow: UIWindow {
    /// View Based Properties
    var toast: Toast? = nil
    var isPresented: Bool = false

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event),
              let rootView = rootViewController?.view else {
            return nil
        }

        if #available(iOS 26, *) {
            if rootView.layer.hitTest(point)?.name == nil {
                return rootView
            }

            return nil
        } else {
            if #unavailable(iOS 18) {
                /// Less than iOS 18
                return hitView == rootView ? nil : hitView
            } else {
                /// iOS 18 to less than iOS 26
                for subview in rootView.subviews.reversed() {
                    /// Finding if any of rootview's subview is receiving hit test
                    let pointInSubView = subview.convert(point, from: rootView)
                    if subview.hitTest(pointInSubView, with: event) != nil {
                        return hitView
                    }
                }

                return nil
            }
        }
    }
}
