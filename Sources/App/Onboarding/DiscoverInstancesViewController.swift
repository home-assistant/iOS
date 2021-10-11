import Lottie
import Shared
import UIKit

class DiscoverInstancesCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        with(textLabel) {
            $0?.textColor = Current.style.onboardingLabel
            $0?.numberOfLines = 0
            $0?.font = UIFont.boldSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize)
        }
        with(detailTextLabel) {
            $0?.textColor = Current.style.onboardingLabelSecondary
            $0?.numberOfLines = 0
            $0?.font = .preferredFont(forTextStyle: .body)
        }
        backgroundView = with(UIView()) {
            $0.backgroundColor = Current.style.onboardingBackground
        }
        selectedBackgroundView = with(UIView()) {
            $0.backgroundColor = UIColor(white: 0, alpha: 0.25)
            $0.layer.cornerRadius = 4.0
        }
        backgroundColor = .clear
        accessoryType = .disclosureIndicator
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class DiscoverInstancesViewController: UIViewController {
    private let discovery = Bonjour()
    private var discoveredInstances: [DiscoveredHomeAssistant] = []

    private var tableView: UITableView?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView?.indexPathsForSelectedRows?.forEach { indexPath in
            tableView?.deselectRow(at: indexPath, animated: animated)
        }

        if !discovery.browserIsRunning {
            startDiscovery()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopDiscovery()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let activityIndicator: UIActivityIndicatorView

        if #available(iOS 13, *) {
            activityIndicator = UIActivityIndicatorView(style: .medium)
        } else {
            activityIndicator = UIActivityIndicatorView(style: .white)
        }

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(customView: activityIndicator),
        ]

        activityIndicator.startAnimating()

        let (_, stackView, _) = UIView.contentStackView(in: view, scrolling: false)

        view.backgroundColor = Current.style.onboardingBackground

        stackView.addArrangedSubview(with(UILabel()) {
            $0.text = L10n.Onboarding.Scanning.title
            Current.style.onboardingTitle($0)
        })

        stackView.addArrangedSubview(with(UITableView(frame: .zero, style: .plain)) {
            tableView = $0
            $0.delegate = self
            $0.dataSource = self

            $0.backgroundView = with(UIView()) {
                $0.backgroundColor = Current.style.onboardingBackground
            }

            // hides the empty separators
            $0.tableFooterView = UIView()

            $0.register(DiscoverInstancesCell.self, forCellReuseIdentifier: "DiscoverInstancesCell")
        })

        NSLayoutConstraint.activate([
            tableView!.widthAnchor.constraint(equalTo: stackView.layoutMarginsGuide.widthAnchor),
        ])

        let manualHintLabel: UILabel = with(UILabel()) {
            $0.text = L10n.Onboarding.Scanning.manualHint
            $0.textColor = Current.style.onboardingLabelSecondary
            $0.font = .preferredFont(forTextStyle: .footnote)
            $0.numberOfLines = 1
            $0.baselineAdjustment = .alignCenters
            $0.minimumScaleFactor = 0.2
            $0.adjustsFontSizeToFitWidth = true
        }
        stackView.addArrangedSubview(manualHintLabel)
        stackView.setCustomSpacing(stackView.spacing / 2.0, after: manualHintLabel)

        stackView.addArrangedSubview(with(UIButton(type: .custom)) {
            $0.setTitle(L10n.Onboarding.Scanning.manual, for: .normal)
            $0.addTarget(self, action: #selector(didSelectManual(_:)), for: .touchUpInside)
            Current.style.onboardingButtonSecondary($0)
        })

        if Current.appConfiguration == .Debug {
            for (idx, instance) in [
                DiscoveredHomeAssistant(
                    baseURL: URL(string: "https://jigsaw.w3.org/HTTP/Basic")!,
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
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1500 * (idx + 1))) { [weak self] in
                    self?.add(discoveredInstance: instance)
                }
            }
        }

        startDiscovery()

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

    deinit {
        stopDiscovery()
    }

    private func startDiscovery() {
        let queue = DispatchQueue(label: "bonjour", target: .global())
        queue.async { [discovery] in
            discovery.stopDiscovery()
            discovery.stopPublish()
            discovery.startDiscovery()
            discovery.startPublish()
        }
    }

    private func stopDiscovery() {
        discovery.stopDiscovery()
        discovery.stopPublish()
    }

    private func add(discoveredInstance: DiscoveredHomeAssistant) {
        tableView?.performBatchUpdates({
            if let existing = discoveredInstances.firstIndex(where: {
                $0.BaseURL == discoveredInstance.BaseURL
            }) {
                discoveredInstances[existing] = discoveredInstance
                tableView?.reloadRows(
                    at: [IndexPath(row: existing, section: 0)],
                    with: .fade
                )
            } else {
                discoveredInstances.append(discoveredInstance)
                tableView?.insertRows(
                    at: [IndexPath(row: discoveredInstances.count - 1, section: 0)],
                    with: .automatic
                )
            }
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
        show(ManualSetupViewController(), sender: self)
    }
}

extension DiscoverInstancesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Current.Log.verbose("Selected row at \(indexPath.row) \(discoveredInstances[indexPath.row])")

        let controller = AuthenticationViewController(instance: discoveredInstances[indexPath.row])
        show(controller, sender: self)
    }
}

extension DiscoverInstancesViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        discoveredInstances.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DiscoverInstancesCell", for: indexPath)

        let instance = discoveredInstances[indexPath.row]

        cell.textLabel?.text = instance.LocationName
        cell.detailTextLabel?.text = instance.BaseURL?.absoluteString

        return cell
    }
}
