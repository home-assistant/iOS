//
//  ConnectionErrorViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/24/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Lottie
import MaterialComponents

class ConnectionErrorViewController: UIViewController {

    @IBOutlet weak var animationView: AnimationView!
    @IBOutlet weak var moreInfoButton: MDCButton!

    var error: ConnectionTestResult?

    override func viewDidLoad() {
        super.viewDidLoad()

        if let navVC = self.navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(self.moreInfoButton)
        }

        self.animationView.animation = Animation.named("error")
        self.animationView.loopMode = .playOnce
        self.animationView.contentMode = .scaleAspectFill
        self.animationView.play()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func moreInfoTapped(_ sender: UIButton) {
    }
}
