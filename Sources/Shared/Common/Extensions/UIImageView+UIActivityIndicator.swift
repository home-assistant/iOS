#if os(iOS)
import Foundation
import UIKit

private var activityIndicatorAssociationKey: UInt8 = 0

public extension UIImageView {
    private var activityIndicator: UIActivityIndicatorView! {
        get {
            objc_getAssociatedObject(self, &activityIndicatorAssociationKey) as? UIActivityIndicatorView
        }
        set(newValue) {
            objc_setAssociatedObject(self, &activityIndicatorAssociationKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    func showActivityIndicator() {
        if activityIndicator == nil {
            if #available(iOS 13, *) {
                self.activityIndicator = UIActivityIndicatorView(style: .large)
            } else {
                activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
            }

            activityIndicator.hidesWhenStopped = true
            activityIndicator.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
            activityIndicator.center = CGPoint(x: frame.size.width / 2, y: frame.size.height / 2)
            activityIndicator.autoresizingMask = [
                .flexibleLeftMargin,
                .flexibleRightMargin,
                .flexibleTopMargin,
                .flexibleBottomMargin,
            ]
            activityIndicator.isUserInteractionEnabled = false

            OperationQueue.main.addOperation({ () in
                self.addSubview(self.activityIndicator)
            })
        }

        OperationQueue.main.addOperation({ () in
            self.activityIndicator.startAnimating()
        })
    }

    func hideActivityIndicator() {
        OperationQueue.main.addOperation({ () in
            self.activityIndicator.stopAnimating()
        })
    }
}
#endif
