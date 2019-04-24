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
import Lottie

class WelcomeViewController: UIViewController {

    @IBOutlet weak var animationView: AnimationView!
    @IBOutlet weak var continueButton: MDCButton!
    override func viewDidLoad() {
        super.viewDidLoad()

        if let navVC = self.navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(self.continueButton)
        }

        self.animationView.animation = Animation.named("ha-loading")

        self.animationView.backgroundBehavior = .pauseAndRestore

        self.animationView.loopMode = .loop
        self.animationView.contentMode = .scaleAspectFill
        self.animationView.play()
        self.animationView.logHierarchyKeypaths()
    }

    @IBAction func continueButton(_ sender: UIButton) {
        self.performSegue(withIdentifier: "discoverInstances", sender: nil)
    }
}
