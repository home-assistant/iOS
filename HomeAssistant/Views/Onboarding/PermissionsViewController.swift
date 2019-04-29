//
//  PermissionsViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/20/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Shared
import MaterialComponents

class PermissionsViewController: UIViewController, PermissionViewChangeDelegate {
    @IBOutlet weak var closeButton: MDCButton!
    @IBOutlet weak var locationPermissionView: PermissionLineItemView!
    @IBOutlet weak var motionPermissionView: PermissionLineItemView!
    @IBOutlet weak var notificationsPermissionView: PermissionLineItemView!
    override func viewDidLoad() {
        super.viewDidLoad()

        if let navVC = self.navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(self.closeButton)
        }

        self.locationPermissionView.delegate = self
        self.motionPermissionView.delegate = self
        self.notificationsPermissionView.delegate = self
    }

    @IBAction func closeButton(_ sender: UIButton) {
        UserDefaults(suiteName: Constants.AppGroupID)?.set(true, forKey: "onboarding_complete")
        Current.onboardingComplete?()
        if let navVC = self.navigationController as? OnboardingNavigationViewController {
            Current.Log.verbose("Dismissing from permissions")
            navVC.dismiss()
        }
    }

    func statusChanged(_ forPermission: PermissionType, _ toStatus: PermissionStatus) {
        Current.Log.verbose("Permission \(forPermission.title) status changed to \(toStatus.description)")
    }
}
