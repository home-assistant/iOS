//
//  ConnectionErrorViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/24/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Lottie
import Shared

class ConnectionErrorViewController: UIViewController {

    @IBOutlet weak var animationView: AnimationView!
    @IBOutlet weak var moreInfoButton: UIButton!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var goBackButton: UIButton!

    var error: Error!

    override func viewDidLoad() {
        super.viewDidLoad()

        if let navVC = self.navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(self.moreInfoButton)
            navVC.styleButton(self.goBackButton)
        }

        self.animationView.animation = Animation.named("error")
        self.animationView.loopMode = .playOnce
        self.animationView.contentMode = .scaleAspectFill
        self.animationView.play()

        self.errorLabel.text = error.localizedDescription

        if let error = error as? ConnectionTestResult {
            if error.kind == .sslExpired || error.kind == .sslUntrusted {
                let text = L10n.Onboarding.ConnectionTestResult.SslContainer.description(error.localizedDescription)
                self.errorLabel.text = text
            }
        } else {
            self.moreInfoButton.isHidden = true
        }
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
        guard let error = self.error as? ConnectionTestResult else { return }
        openURLInBrowser(error.DocumentationURL, self)
    }
}
