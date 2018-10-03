//
//  NotificationViewController.swift
//  NotificationContentExtension
//
//  Created by Robbie Trencheny on 9/9/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import MBProgressHUD

enum NotificationCategories: String {
    case map
    case camera
}

class NotificationViewController: UIViewController, UNNotificationContentExtension {

    var hud: MBProgressHUD?

    var controller: NotificationCategory?

    func didReceive(_ notification: UNNotification) {
        if let category = NotificationCategories(rawValue: notification.request.content.categoryIdentifier) {
            print("Received a", category, "notification")

            let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            let loadTxt = L10n.Extensions.NotificationContent.Hud.loading(category.rawValue)
            hud.detailsLabel.text = loadTxt
            hud.offset = CGPoint(x: 0, y: -MBProgressMaxOffset+50)
            self.hud = hud

            switch category {
            case .camera:
                controller = CameraViewController()
            case .map:
                controller = MapViewController()
            }

            controller!.didReceive(notification, view: self.view!, extensionContext: self.extensionContext, hud: hud,
                                   completionHandler: { (errorText) in
                                     if let errorText = errorText {
                                         self.showErrorLabel(message: errorText)
                                     }
            })
        } else {
            print("Unknown category!!!!!", notification.request.content.categoryIdentifier)
        }
    }

    func showErrorLabel(message: String) {
        self.hud?.hide(animated: true)
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 60))
        label.center.y = self.view.center.y
        label.textAlignment = .center
        label.textColor = .red
        label.text = message
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        self.view.addSubview(label)
    }

    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType {
        if let buttonType = controller?.mediaPlayPauseButtonType {
            return buttonType
        }
        return .none
    }

    var mediaPlayPauseButtonFrame: CGRect {
        if let frame = controller?.mediaPlayPauseButtonFrame {
            return frame
        }

        return CGRect(x: 0, y: 0, width: 0, height: 0)
    }

    public func mediaPlay() {
        if let isMediaExtension = controller?.isMediaExtension, isMediaExtension {
            return controller!.mediaPlay()
        }
    }

    public func mediaPause() {
        if let isMediaExtension = controller?.isMediaExtension, isMediaExtension {
            return controller!.mediaPause()
        }
    }

}

protocol NotificationCategory: NSObjectProtocol {

    // This will be called to send the notification to be displayed by
    // the extension. If the extension is being displayed and more related
    // notifications arrive (eg. more messages for the same conversation)
    // the same method will be called for each new notification.
    func didReceive(_ notification: UNNotification, view: UIView, extensionContext: NSExtensionContext?,
                    hud: MBProgressHUD, completionHandler: @escaping (String?) -> Void)

}

extension NotificationCategory {
    var isMediaExtension: Bool {
        return false
    }

    // If implemented, the method will be called when the user taps on one
    // of the notification actions. The completion handler can be called
    // after handling the action to dismiss the notification and forward the
    // action to the app if necessary.
    func didReceive(_ response: UNNotificationResponse,
                    completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void) {

    }

    // Implementing this method and returning a button type other that "None" will
    // make the notification attempt to draw a play/pause button correctly styled
    // for that type.
    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType? {
        return nil
    }

    // Implementing this method and returning a non-empty frame will make
    // the notification draw a button that allows the user to play and pause
    // media content embedded in the notification.
    var mediaPlayPauseButtonFrame: CGRect? {
        return nil
    }

    // The tint color to use for the button.
    var mediaPlayPauseButtonTintColor: UIColor? {
        return nil
    }

    // Called when the user taps the play or pause button.
    func mediaPlay() {

    }

    func mediaPause() {

    }
}
