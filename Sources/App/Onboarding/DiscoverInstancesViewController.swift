import Lottie
import Shared
import UIKit

class DiscoverInstancesViewController: UIViewController {
    private let discovery = Bonjour()
    private var discoveredInstances: [DiscoveredHomeAssistant] = []

    @IBOutlet private var tableView: UITableView!
    @IBOutlet private var animationView: AnimationView!
    @IBOutlet private var manualButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        if let navVC = navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(manualButton)
        }

        if Current.appConfiguration == .Debug {
            for (idx, instance) in [
                DiscoveredHomeAssistant(
                    baseURL: URL(string: "https://jigsaw.w3.org/HTTP/Basic/api/discovery_info")!,
                    name: "Basic Auth",
                    version: "0.92.0"
                ),
                DiscoveredHomeAssistant(
                    baseURL: URL(string: "https://self-signed.badssl.com/")!,
                    name: "Self signed SSL",
                    version: "0.92.0"
                ),
                DiscoveredHomeAssistant(
                    baseURL: URL(string: "https://client.badssl.com/")!,
                    name: "Client Cert",
                    version: "0.92.0"
                ),
                DiscoveredHomeAssistant(
                    baseURL: URL(string: "http://http.badssl.com/")!,
                    name: "HTTP",
                    version: "0.92.0"
                ),
            ].enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1500 * idx)) { [weak self] in
                    self?.add(discoveredInstance: instance)
                }
            }
        }

        animationView.superview?.bringSubviewToFront(animationView)

        // hides the empty separators
        tableView.tableFooterView = UIView()

        animationView.contentMode = .scaleAspectFill
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.animation = Animation.named("ha-loading")
        animationView.play(
            fromMarker: "Circle Fill Begins",
            toMarker: "Deform Begins",
            loopMode: .loop,
            completion: nil
        )

        let queue = DispatchQueue(label: Bundle.main.bundleIdentifier!, attributes: [])
        queue.async {
            self.discovery.stopDiscovery()
            self.discovery.stopPublish()

            self.discovery.startDiscovery()
            self.discovery.startPublish()
        }

        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(HomeAssistantDiscovered(_:)),
            name: NSNotification.Name(rawValue: "homeassistant.discovered"),
            object: nil
        )

        center.addObserver(
            self,
            selector: #selector(HomeAssistantUndiscovered(_:)),
            name: NSNotification.Name(rawValue: "homeassistant.undiscovered"),
            object: nil
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        discovery.stopDiscovery()
        discovery.stopPublish()
    }

    deinit {
        self.discovery.stopDiscovery()
        self.discovery.stopPublish()
    }

    private func add(discoveredInstance: DiscoveredHomeAssistant) {
        guard discoveredInstances.contains(where: {
            $0.BaseURL == discoveredInstance.BaseURL
        }) == false else {
            // already discovered
            return
        }

        discoveredInstances.append(discoveredInstance)

        if discoveredInstances.count == 3 {
            UIView.transition(.promise, with: animationView, duration: 1.0) { [weak animationView] in
                animationView?.alpha = 0
            }.done { [weak animationView] _ in
                animationView?.stop()
            }
        }

        tableView.performBatchUpdates({
            tableView.insertRows(
                at: [IndexPath(row: discoveredInstances.count - 1, section: 0)],
                with: .automatic
            )
        }, completion: nil)
    }

    @objc func HomeAssistantDiscovered(_ notification: Notification) {
        if let userInfo = notification.userInfo as? [String: Any] {
            guard let discoveryInfo = DiscoveredHomeAssistant(JSON: userInfo) else {
                Current.Log.error("Unable to parse discovered HA Instance")
                return
            }

            add(discoveredInstance: discoveryInfo)
        }
    }

    @objc func HomeAssistantUndiscovered(_ notification: Notification) {
        if let userInfo = notification.userInfo, let name = userInfo["name"] as? String {
            Current.Log.verbose("Remove discovered instance \(name)")
        }
    }

    @IBAction func didSelectManual(_ sender: UIButton) {
        show(StoryboardScene.Onboarding.manualSetup.instantiate(), sender: self)
    }
}

extension DiscoverInstancesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Current.Log.verbose("Selected row at \(indexPath.row) \(discoveredInstances[indexPath.row])")

        let controller = StoryboardScene.Onboarding.authentication.instantiate()
        controller.instance = discoveredInstances[indexPath.row]
        show(controller, sender: self)
    }
}

extension DiscoverInstancesViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        discoveredInstances.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "discoveredInstanceCell", for: indexPath)

        let instance = discoveredInstances[indexPath.row]

        cell.textLabel?.text = instance.LocationName
        cell.detailTextLabel?.text = instance.BaseURL?.absoluteString

        return cell
    }
}
