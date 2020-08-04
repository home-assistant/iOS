//
//  OnboardingNavigationViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/22/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Eureka
import Shared
import MaterialComponents.MaterialButtons
import MaterialComponents.MaterialButtons_Theming
import Reachability

class OnboardingNavigationViewController: UINavigationController, RowControllerType {

    public var onDismissCallback: ((UIViewController) -> Void)?

    // swiftlint:disable:next force_try
    let reachability = try! Reachability()

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            // Always adopt a light interface style.
            overrideUserInterfaceStyle = .light
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        do {
            try reachability.startNotifier()
        } catch let error {
            Current.Log.error("Unable to start Reachability notifier: \(error)")
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.reachability.stopNotifier()
    }

    func dismiss() {
        self.dismiss(animated: true, completion: nil)
        onDismissCallback?(self)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    func styleButton(_ button: MDCButton) {
        let containerScheme = MDCContainerScheme()
        if #available(iOS 13, *) {
            containerScheme.colorScheme.primaryColor = .systemBackground
        } else {
            containerScheme.colorScheme.primaryColor = .white
        }
        containerScheme.colorScheme.secondaryColor = Constants.tintColor
        button.applyContainedTheme(withScheme: containerScheme)

        button.setTitleColor(Constants.tintColor, for: .normal)

        button.isUppercaseTitle = true

        if let text = button.titleLabel?.text {
            button.titleLabel?.text = text.uppercased()
            button.setTitle(text.uppercased(), for: .normal)
        }
    }
}
