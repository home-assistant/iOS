//
//  ClientEventPayloadViewController.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 8/25/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import Shared

/// View controller responsible for displaying the details of a client event. 
class ClientEventPayloadViewController: UIViewController {
    @IBOutlet weak var textView: UITextView!
    private var jsonString: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.textView.text = self.jsonString
    }

    func showEvent(_ event: ClientEvent) {
        guard let payloadObject = event.jsonPayload else {
            return
        }

        do {
            let data: Data = try JSONSerialization.data(withJSONObject: payloadObject as Any,
                                                        options: .prettyPrinted)
            self.jsonString  = String(data: data, encoding: .utf8)
        } catch _ {
            print("Error printing event")
        }
    }
}
