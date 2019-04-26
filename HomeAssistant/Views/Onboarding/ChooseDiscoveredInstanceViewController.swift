//
//  ChooseDiscoveredInstanceViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/21/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Shared
import MaterialComponents

class ChooseDiscoveredInstanceViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var manualButton: MDCButton!

    var instances: [DiscoveredHomeAssistant] = []

    var selectedInstance: DiscoveredHomeAssistant?

    override func viewDidLoad() {
        super.viewDidLoad()

        if let navVC = self.navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(self.manualButton)
        }

        print("Received instances", self.instances)

        self.statusLabel.text = "We found \(self.instances.count) Home Assistants on your network"
    }

    @IBAction func continueManually(_ sender: Any) {
        print("User wants to continue manually")
        self.perform(segue: StoryboardSegue.Onboarding.continueManually, sender: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueType = StoryboardSegue.Onboarding(segue) else { return }
        if segueType == .setupDiscoveredInstance, let vc = segue.destination as? AuthenticationViewController {
            vc.instance = self.selectedInstance
        }
    }
}

extension ChooseDiscoveredInstanceViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectedInstance = self.instances[indexPath.row]
        print("Selected row at \(indexPath.row) \(self.selectedInstance)")
        self.perform(segue: StoryboardSegue.Onboarding.setupDiscoveredInstance, sender: self.selectedInstance)
    }
}

extension ChooseDiscoveredInstanceViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.instances.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "discoveredInstanceCell", for: indexPath)

        let instance = self.instances[indexPath.row]

        cell.textLabel?.text = instance.LocationName
        cell.detailTextLabel?.text = instance.BaseURL?.absoluteString

        return cell
    }

}
