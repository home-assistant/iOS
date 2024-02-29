import PromiseKit
import Shared
import UIKit

class OnboardingScanningInstanceCell: UITableViewCell {
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

    public var isLoading: Bool = false {
        didSet {
            if isLoading {
                accessoryType = .none
                let activityIndicator: UIActivityIndicatorView = .init(style: .medium)
                accessoryView = activityIndicator
                activityIndicator.startAnimating()
            } else {
                accessoryView = nil
                accessoryType = .disclosureIndicator
            }
        }
    }
}

class OnboardingScanningViewController: UIViewController {
    private let discovery = Bonjour()
    private var discoveredInstances: [DiscoveredHomeAssistant] = []

    private var tableView: UITableView?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView?.indexPathsForSelectedRows?.forEach { indexPath in
            tableView?.deselectRow(at: indexPath, animated: animated)
        }

        discovery.start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        discovery.stop()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let activityIndicator: UIActivityIndicatorView

        activityIndicator = UIActivityIndicatorView(style: .medium)

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
            $0.cellLayoutMarginsFollowReadableWidth = true

            $0.backgroundColor = Current.style.onboardingBackground
            $0.backgroundView = with(UIView()) {
                $0.backgroundColor = Current.style.onboardingBackground
            }

            // hides the empty separators
            $0.tableFooterView = UIView()

            $0.register(OnboardingScanningInstanceCell.self, forCellReuseIdentifier: "OnboardingScanningInstanceCell")
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

        discovery.observer = self

        if Current.appConfiguration == .debug {
            for (idx, instance) in [
                DiscoveredHomeAssistant(
                    manualURL: URL(string: "https://jigsaw.w3.org/HTTP/Basic")!,
                    name: "Basic Auth"
                ),
                DiscoveredHomeAssistant(
                    manualURL: URL(string: "http://httpbin.org/digest-auth/asdf")!,
                    name: "Digest Auth"
                ),
                DiscoveredHomeAssistant(
                    manualURL: URL(string: "https://self-signed.badssl.com/")!,
                    name: "Self signed SSL"
                ),
                DiscoveredHomeAssistant(
                    manualURL: URL(string: "https://client.badssl.com/")!,
                    name: "Client Cert"
                ),
                DiscoveredHomeAssistant(
                    manualURL: URL(string: "https://expired.badssl.com/")!,
                    name: "Expired"
                ),
                DiscoveredHomeAssistant(
                    manualURL: URL(string: "https://httpbin.org/statuses/404")!,
                    name: "Status Code 404"
                ),
            ].enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1500 * (idx + 1))) { [weak self] in
                    self?.add(discoveredInstance: instance)
                }
            }
        }
    }

    deinit {
        discovery.stop()
    }

    private func add(discoveredInstance: DiscoveredHomeAssistant) {
        tableView?.performBatchUpdates({
            if let existing = discoveredInstances.firstIndex(where: {
                ($0.uuid != nil && $0.uuid == discoveredInstance.uuid)
                    || $0.internalOrExternalURL == discoveredInstance.internalOrExternalURL
            }) {
                discoveredInstances[existing] = discoveredInstance
                tableView?.reloadRows(
                    at: [IndexPath(row: existing, section: 0)],
                    with: .none
                )
            } else {
                UIAccessibility.post(notification: .announcement, argument: NSAttributedString(
                    string: L10n.Onboarding.Scanning.discoveredAnnouncement(discoveredInstance.locationName),
                    attributes: [.accessibilitySpeechQueueAnnouncement: true]
                ))
                discoveredInstances.append(discoveredInstance)
                tableView?.insertRows(
                    at: [IndexPath(row: discoveredInstances.count - 1, section: 0)],
                    with: .automatic
                )
            }
        }, completion: nil)
    }

    private func remove(forName name: String) {
        tableView?.performBatchUpdates({
            if let existing = discoveredInstances.firstIndex(where: {
                $0.bonjourName == name
            }) {
                discoveredInstances.remove(at: existing)
                tableView?.deleteRows(
                    at: [IndexPath(row: existing, section: 0)],
                    with: .automatic
                )
            }
        }, completion: nil)
    }

    @objc private func didSelectManual(_ sender: UIButton) {
        show(OnboardingManualURLViewController(), sender: self)
    }
}

extension OnboardingScanningViewController: BonjourObserver {
    func bonjour(_ bonjour: Bonjour, didAdd instance: DiscoveredHomeAssistant) {
        add(discoveredInstance: instance)
    }

    func bonjour(_ bonjour: Bonjour, didRemoveInstanceWithName name: String) {
        remove(forName: name)
    }
}

extension OnboardingScanningViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let instance = discoveredInstances[indexPath.row]
        let cell = tableView.cellForRow(at: indexPath) as? OnboardingScanningInstanceCell

        Current.Log.verbose("Selected row at \(indexPath.row) \(instance)")

        cell?.isLoading = true
        tableView.isUserInteractionEnabled = false

        let authentication = OnboardingAuth()

        firstly {
            authentication.authenticate(to: instance, sender: self)
        }.ensure {
            cell?.isLoading = false
            tableView.isUserInteractionEnabled = true
            tableView.deselectRow(at: indexPath, animated: true)
        }.done { [self] server in
            show(authentication.successController(server: server), sender: self)
        }.catch { [self] error in
            show(authentication.failureController(error: error), sender: self)
        }
    }
}

extension OnboardingScanningViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        discoveredInstances.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OnboardingScanningInstanceCell", for: indexPath)

        let instance = discoveredInstances[indexPath.row]

        cell.textLabel?.text = instance.locationName
        cell.detailTextLabel?.text = instance.internalOrExternalURL.absoluteString
        cell.accessibilityLabel = instance.locationName
        cell.accessibilityAttributedValue = with(NSMutableAttributedString()) { overall in
            for part in [
                instance.internalOrExternalURL.host,
                instance.internalOrExternalURL.port.flatMap { String(describing: $0) },
            ].compactMap({ $0 }) {
                overall
                    .append(NSAttributedString(
                        string: part,
                        attributes: [.accessibilitySpeechPunctuation: true as NSNumber]
                    ))
                overall.append(NSAttributedString(string: ", "))
            }
        }

        return cell
    }
}
