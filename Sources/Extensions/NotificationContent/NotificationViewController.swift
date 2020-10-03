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
import KeychainAccess
import Shared
import PromiseKit
import Alamofire
import MBProgressHUD

enum NotificationCategories: String {
    case map
    case map1
    case map2
    case map3
    case map4
    case camera
    case camera1
    case camera2
    case camera3
    case camera4
}

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    var activeViewController: (UIViewController & NotificationCategory)? {
        willSet {
            activeViewController?.willMove(toParent: nil)
            newValue.flatMap { addChild($0) }
        }
        didSet {
            oldValue?.view.removeFromSuperview()
            oldValue?.removeFromParent()

            if let viewController = activeViewController {
                view.addSubview(viewController.view)
                viewController.view.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    viewController.view.topAnchor.constraint(equalTo: view.topAnchor),
                    viewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    viewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    viewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                ])

                viewController.didMove(toParent: self)
            }
        }
    }

    func didReceive(_ notification: UNNotification) {
        let catID = notification.request.content.categoryIdentifier.lowercased()
        guard let category = NotificationCategories(rawValue: catID) else {
            Current.Log.warning("Unknown category \(notification.request.content.categoryIdentifier)")
            return
        }

        Current.Log.verbose("Received a \(category) notif with userInfo \(notification.request.content.userInfo)")
        let controller: (UIViewController & NotificationCategory)

        switch category {
        case .camera, .camera1, .camera2, .camera3, .camera4:
            controller = CameraViewController()
        case .map, .map1, .map2, .map3, .map4:
            controller = MapViewController()
        }

        let hud: MBProgressHUD? = {
            guard controller.mediaPlayPauseButtonType == .none else {
                // don't show the HUD for a screen that has pause/play because it already acts like a loading indicator
                return nil
            }

            let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            let loadTxt = L10n.Extensions.NotificationContent.Hud.loading(category.rawValue)
            hud.offset = CGPoint(x: 0, y: -MBProgressMaxOffset+50)
            hud.detailsLabel.text = loadTxt
            return hud
        }()

        activeViewController = controller

        controller.didReceive(
            notification: notification,
            extensionContext: extensionContext
        ).ensure {
            hud?.hide(animated: true)
        }.catch { [weak self] error in
            Current.Log.error("finally failed: \(error)")
            self?.activeViewController = NotificationErrorViewController(error: error)
        }
    }

    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType {
        activeViewController?.mediaPlayPauseButtonType ?? .none
    }

    var mediaPlayPauseButtonFrame: CGRect {
        return CGRect(
            x: view.bounds.width / 2.0 - 22,
            y: view.bounds.height / 2.0 - 22,
            width: 44,
            height: 44
        )
    }

    public func mediaPlay() {
        activeViewController?.mediaPlay()
    }

    public func mediaPause() {
        activeViewController?.mediaPause()
    }
}

protocol NotificationCategory: NSObjectProtocol {
    // This will be called to send the notification to be displayed by
    // the extension. If the extension is being displayed and more related
    // notifications arrive (eg. more messages for the same conversation)
    // the same method will be called for each new notification.
    func didReceive(
        notification: UNNotification,
        extensionContext: NSExtensionContext?
    ) -> Promise<Void>

    // Implementing this method and returning a button type other that "None" will
    // make the notification attempt to draw a play/pause button correctly styled
    // for that type.
    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType { get }

    // Implementing this method and returning a non-empty frame will make
    // the notification draw a button that allows the user to play and pause
    // media content embedded in the notification.
    var mediaPlayPauseButtonFrame: CGRect? { get }

    // Called when the user taps the play or pause button.
    func mediaPlay()
    func mediaPause()
}
