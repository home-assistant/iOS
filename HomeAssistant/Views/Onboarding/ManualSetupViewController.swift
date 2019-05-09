//
//  ManualSetupViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/20/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Shared
import MaterialComponents.MaterialButtons

class ManualSetupViewController: UIViewController {

    @IBOutlet weak var connectButton: MDCButton!
    @IBOutlet weak var urlField: UITextField!

    public var notOnWifi: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()

        if let navVC = self.navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(self.connectButton)
        }

        // Keyboard avoidance adapted from https://stackoverflow.com/a/27135992/486182
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)

    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @IBAction func connectButtonTapped(_ sender: UIButton) {
        Current.Log.verbose("Connect button tapped")
        self.perform(segue: StoryboardSegue.Onboarding.setupManualInstance)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueType = StoryboardSegue.Onboarding(segue) else { return }
        if segueType == .setupManualInstance, let vc = segue.destination as? AuthenticationViewController {
            guard let fieldVal = self.urlField.text else {
                // swiftlint:disable:next line_length
                Current.Log.error("Unable to get text! Field is \(String(describing: self.urlField)), text \(String(describing: self.urlField.text))")
                return
            }
            guard let url = URL(string: fieldVal) else {
                Current.Log.error("Unable to convert text to URL! Text was \(fieldVal)")
                return
            }

            vc.instance = DiscoveredHomeAssistant(baseURL: url, name: "Manual", version: "0.92.0")
        }
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }
        guard let keyboardSize = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        if self.view.frame.origin.y == 0 {
            self.view.frame.origin.y -= keyboardSize.cgRectValue.height / 2
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }
        guard let keyboardSize = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        if self.view.frame.origin.y != 0 {
            self.view.frame.origin.y += keyboardSize.cgRectValue.height / 2
        }
    }

}
