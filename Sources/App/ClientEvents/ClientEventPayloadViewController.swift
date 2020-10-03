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

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(share(_:)))
        ]
        self.textView.text = self.jsonString
    }

    @objc private func share(_ sender: UIBarButtonItem) {
        let controller = UIActivityViewController(activityItems: [jsonString ?? "?"], applicationActivities: nil)
        with(controller.popoverPresentationController) {
            $0?.barButtonItem = sender
        }
        present(controller, animated: true, completion: nil)
    }

    func showEvent(_ event: ClientEvent) {
        jsonString = event.jsonPayloadDescription
    }
}
