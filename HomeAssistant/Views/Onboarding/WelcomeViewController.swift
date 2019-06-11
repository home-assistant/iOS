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
import Reachability

class WelcomeViewController: UIViewController {

    @IBOutlet weak var animationView: AnimationView!
    @IBOutlet weak var continueButton: MDCButton!
    @IBOutlet weak var wifiWarningLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        let reachability = (self.navigationController as? OnboardingNavigationViewController)?.reachability
        self.wifiWarningLabel.isHidden = reachability?.connection == .wifi

        if let navVC = self.navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(self.continueButton)
        }

        self.animationView.animation = Animation.named("ha-loading")
        self.animationView.loopMode = .playOnce
        self.animationView.play(toMarker: "Circles Formed")

        // FIXME: This is a hack due to changes in CNCopyCurrentNetworkInfo. Move permissions screen to first position to properly fix. More info: https://twitter.com/Robbie/status/1138320059867123712
        PermissionType.location.request { (success, status) in
            print("Request permission gave us", success, status)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let reachability = (self.navigationController as? OnboardingNavigationViewController)?.reachability

        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(_:)),
                                               name: .reachabilityChanged, object: reachability)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        let reachability = (self.navigationController as? OnboardingNavigationViewController)?.reachability
        NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: reachability)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueType = StoryboardSegue.Onboarding(segue) else { return }
        if segueType == .manuallyConnectInstance, let vc = segue.destination as? ManualSetupViewController {
            vc.notOnWifi = false
        }
    }

    @IBAction func continueButton(_ sender: UIButton) {
        if self.wifiWarningLabel.isHidden {
            self.perform(segue: StoryboardSegue.Onboarding.discoverInstances, sender: nil)
        } else {
            self.perform(segue: StoryboardSegue.Onboarding.manuallyConnectInstance, sender: nil)
        }
    }

    @objc func reachabilityChanged(_ note: Notification) {
        guard let reachability = note.object as? Reachability else {
            Current.Log.warning("Couldn't cast notification object as Reachability")
            return
        }

        Current.Log.verbose("Reachability changed to \(reachability.connection.description)")
        self.wifiWarningLabel.isHidden = (reachability.connection == .wifi)
    }
}
