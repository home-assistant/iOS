//
//  ManualSetupViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/20/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit

class ManualSetupViewController: UIViewController {

    @IBOutlet weak var urlField: UITextField!

    public var notOnWifi: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func connectButtonTapped(_ sender: UIButton) {
        print("Connect button tapped")
    }

}
