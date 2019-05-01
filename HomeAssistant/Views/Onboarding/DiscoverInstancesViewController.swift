//
//  DiscoverInstancesViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/21/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Shared
import Lottie
import MaterialComponents

class DiscoverInstancesViewController: UIViewController {

    let discovery = Bonjour()

    @IBOutlet weak var animationView: AnimationView!
    @IBOutlet weak var manualButton: MDCButton!

    var discoveredInstances: [DiscoveredHomeAssistant] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        if let navVC = self.navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(self.manualButton)
        }

        if Current.appConfiguration == .Debug {
            discoveredInstances = [
                DiscoveredHomeAssistant(baseURL: URL(string: "https://jigsaw.w3.org/HTTP/Basic/api/discovery_info")!,
                                        name: "Basic Auth", version: "0.92.0", ssl: true),
                DiscoveredHomeAssistant(baseURL: URL(string: "https://self-signed.badssl.com/")!,
                                        name: "Self signed SSL", version: "0.92.0", ssl: true),
                DiscoveredHomeAssistant(baseURL: URL(string: "https://client.badssl.com/")!, name: "Client Cert",
                                        version: "0.92.0", ssl: true),
                DiscoveredHomeAssistant(baseURL: URL(string: "http://http.badssl.com/")!, name: "HTTP",
                                        version: "0.92.0", ssl: false)
            ]
        }

        self.animationView.contentMode = .scaleAspectFill
        self.animationView.backgroundBehavior = .pauseAndRestore
        self.animationView.animation = Animation.named("ha-loading")
        self.animationView.play(fromMarker: "Circle Fill Begins", toMarker: "Deform Begins", loopMode: .loop,
                                completion: nil)

        let queue = DispatchQueue(label: Bundle.main.bundleIdentifier!, attributes: [])
        queue.async {
            self.discovery.stopDiscovery()
            self.discovery.stopPublish()

            self.discovery.startDiscovery()
            self.discovery.startPublish()

            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
                if self.discovery.browserIsRunning && self.discovery.publishIsRunning {
                    self.perform(segue: StoryboardSegue.Onboarding.chooseDiscoveredInstance, sender: nil)
                }

                self.discovery.stopDiscovery()
                self.discovery.stopPublish()
            })
        }

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(HomeAssistantDiscovered(_:)),
                           name: NSNotification.Name(rawValue: "homeassistant.discovered"), object: nil)

        center.addObserver(self, selector: #selector(HomeAssistantUndiscovered(_:)),
                           name: NSNotification.Name(rawValue: "homeassistant.undiscovered"), object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        self.discovery.stopDiscovery()
        self.discovery.stopPublish()
    }

    deinit {
        self.discovery.stopDiscovery()
        self.discovery.stopPublish()
    }

    @objc func HomeAssistantDiscovered(_ notification: Notification) {
        if let userInfo = (notification as Notification).userInfo as? [String: Any] {
            guard let discoveryInfo = DiscoveredHomeAssistant(JSON: userInfo) else {
                Current.clientEventStore.addEvent(ClientEvent(text: "Unable to parse discovered HA Instance",
                                                              type: .unknown, payload: userInfo))
                return
            }

            self.discoveredInstances.append(discoveryInfo)
        }
    }

    @objc func HomeAssistantUndiscovered(_ notification: Notification) {
        if let userInfo = (notification as Notification).userInfo, let name = userInfo["name"] as? String {
            Current.Log.verbose("Remove discovered instance \(name)")
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueType = StoryboardSegue.Onboarding(segue) else { return }
        if segueType == .chooseDiscoveredInstance,
            let vc = segue.destination as? ChooseDiscoveredInstanceViewController {
            vc.instances = self.discoveredInstances.sorted(by: { (a, b) -> Bool in
                return a.LocationName < b.LocationName
            })
        }
    }
}
