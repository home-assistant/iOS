//
//  UIImageView+UIActivityIndicator.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 2/19/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

#if os(iOS)
import Foundation
import UIKit

private var activityIndicatorAssociationKey: UInt8 = 0

public extension UIImageView {
    private var activityIndicator: UIActivityIndicatorView! {
        get {
            return objc_getAssociatedObject(self, &activityIndicatorAssociationKey) as? UIActivityIndicatorView
        }
        set(newValue) {
            objc_setAssociatedObject(self, &activityIndicatorAssociationKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    func showActivityIndicator() {

        if self.activityIndicator == nil {
            if #available(iOS 13, *) {
                self.activityIndicator = UIActivityIndicatorView(style: .large)
            } else {
                self.activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
            }

            self.activityIndicator.hidesWhenStopped = true
            self.activityIndicator.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
            self.activityIndicator.center = CGPoint(x: self.frame.size.width / 2, y: self.frame.size.height / 2)
            self.activityIndicator.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin,
                                                       .flexibleTopMargin, .flexibleBottomMargin]
            self.activityIndicator.isUserInteractionEnabled = false

            OperationQueue.main.addOperation({ () -> Void in
                self.addSubview(self.activityIndicator)
            })
        }

        OperationQueue.main.addOperation({ () -> Void in
            self.activityIndicator.startAnimating()
        })
    }

    func hideActivityIndicator() {
        OperationQueue.main.addOperation({ () -> Void in
            self.activityIndicator.stopAnimating()
        })
    }
}
#endif
