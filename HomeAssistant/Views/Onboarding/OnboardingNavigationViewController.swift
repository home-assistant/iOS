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

    func styleButton(_ button: UIButton) {
        button.layer.cornerRadius = 6.0
        button.layer.masksToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        button.titleLabel?.font = UIFont.systemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .callout).pointSize,
            weight: .bold
        )
        button.setTitleColor(Constants.tintColor, for: .normal)

        if #available(iOS 13, *) {
            button.setBackgroundImage(
                UIImage(size: CGSize(width: 1, height: 1), color: .systemBackground),
                for: .normal
            )
        } else {
            button.setBackgroundImage(
                UIImage(size: CGSize(width: 1, height: 1), color: .white),
                for: .normal
            )
        }

        if let title = button.title(for: .normal) {
            button.setTitle(title.localizedUppercase, for: .normal)
        }
    }
}
