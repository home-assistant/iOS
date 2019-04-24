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
import MaterialComponents.MaterialButtons_ButtonThemer
import MaterialComponents.MaterialButtons_ColorThemer
import MaterialComponents.MDCContainedButtonThemer

class OnboardingNavigationViewController: UINavigationController, RowControllerType {

    public var onDismissCallback: ((UIViewController) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    func dismiss() {
        print("dismissing!")
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
        let buttonScheme = MDCButtonScheme()
        MDCContainedButtonThemer.applyScheme(buttonScheme, to: button)

        let containerScheme = MDCSemanticColorScheme(defaults: .material201804)
        containerScheme.primaryColor = .white
        containerScheme.secondaryColor = Constants.blue
        MDCContainedButtonColorThemer.applySemanticColorScheme(containerScheme, to: button)

        button.setTitleColor(Constants.blue, for: .normal)
    }
}
