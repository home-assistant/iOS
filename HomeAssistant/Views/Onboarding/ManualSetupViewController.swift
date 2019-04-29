//
//  ManualSetupViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/20/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Shared

class ManualSetupViewController: UIViewController {

    @IBOutlet weak var urlField: UITextField!

    public var notOnWifi: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func connectButtonTapped(_ sender: UIButton) {
        Current.Log.verbose("Connect button tapped")
        self.perform(segue: StoryboardSegue.Onboarding.setupManualInstance)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueType = StoryboardSegue.Onboarding(segue) else { return }
        if segueType == .setupManualInstance, let vc = segue.destination as? AuthenticationViewController {
            guard let fieldVal = self.urlField.text, let url = URL(string: fieldVal) else { return }

            let isSSL = url.scheme == "https"
            vc.instance = DiscoveredHomeAssistant(baseURL: url, name: "Manual", version: "0.92.0", ssl: isSSL)
        }
    }

}
