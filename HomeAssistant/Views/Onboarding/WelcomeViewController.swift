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

class WelcomeViewController: UIViewController {

    @IBOutlet weak var animatedLogoView: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()

        // self.animatedLogoView.image = UIImage.animatedImageNamed("ha-loading-", duration: 5.0)
    }

    @IBAction func continueButton(_ sender: UIButton) {
        self.performSegue(withIdentifier: "discoverInstances", sender: nil)
    }
}
