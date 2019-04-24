//
//  OnboardingViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/20/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Shared
import Eureka
import MaterialComponents.MaterialButtons

class WelcomeViewController: UIViewController {

    @IBOutlet weak var animatedLogoView: UIImageView!
    @IBOutlet weak var continueButton: MDCButton!
    override func viewDidLoad() {
        super.viewDidLoad()

        if let navVC = self.navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(self.continueButton)
        }

        self.animatedLogoView.image = UIImage.animatedImageNamed("ha-loading-", duration: 5.0)
    }

    @IBAction func continueButton(_ sender: UIButton) {
        self.performSegue(withIdentifier: "discoverInstances", sender: nil)
    }
}
