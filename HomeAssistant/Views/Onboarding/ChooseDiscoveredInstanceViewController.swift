//
//  ChooseDiscoveredInstanceViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/21/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Shared

class ChooseDiscoveredInstanceViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    @IBOutlet weak var statusLabel: UILabel!

    var instances: [DiscoveryInfoResponse] = []

    var selectedInstance: DiscoveryInfoResponse?

    override func viewDidLoad() {
        super.viewDidLoad()

        print("Received instances", self.instances)

        self.statusLabel.text = "We found \(self.instances.count) Home Assistants on your network"
    }

    @IBAction func continueManually(_ sender: Any) {
        print("User wants to continue manually")
        self.performSegue(withIdentifier: "continueManually", sender: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "setupDiscoveredInstance", let vc = segue.destination as? ConnectInstanceViewController {
            vc.instance = self.selectedInstance
        }
    }
}

extension ChooseDiscoveredInstanceViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectedInstance = self.instances[indexPath.row]
        print("Selected row at \(indexPath.row) \(self.selectedInstance)")
        self.performSegue(withIdentifier: "setupDiscoveredInstance", sender: self.selectedInstance)
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
