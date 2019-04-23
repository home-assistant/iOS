//
//  OnboardingNavigationViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/22/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Eureka

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

}
