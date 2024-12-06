import Eureka
import PromiseKit
import RealmSwift
import Shared

class NotificationRateLimitListViewController: HAFormViewController {
    let utc = TimeZone(identifier: "UTC")!
    let refreshControl = UIRefreshControl()

    private var initialPromise: Promise<RateLimitResponse>?

    static func newPromise() -> Promise<RateLimitResponse> {
        if let pushID = Current.settingsStore.pushID {
            return NotificationRateLimitsAPI.rateLimits(pushID: pushID)
        } else {
            return .init(error: RateLimitError.noPushId)
        }
    }

    init(initialPromise: Promise<RateLimitResponse>?) {
        self.initialPromise = initialPromise
        super.init()
    }

    var rateLimitDidChange: (RateLimitResponse) -> Void = { _ in }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupTimer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        teardownTimer()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.SettingsDetails.Notifications.RateLimits.header

        if Current.isCatalyst {
            navigationItem.rightBarButtonItems = [
                UIBarButtonItem(
                    barButtonSystemItem: .refresh,
                    target: self,
                    action: #selector(refresh)
                ),
            ]
        } else {
            tableView.refreshControl = refreshControl
            refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        }

        refresh()

        form +++ Section {
            $0.tag = "rateLimits"
        }
    }

    private var timer: Timer? {
        willSet {
            timer?.invalidate()
        }
    }

    private func setupTimer() {
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(updateTimer),
            userInfo: nil,
            repeats: true
        )
    }

    private func teardownTimer() {
        timer = nil
    }

    private enum RateLimitError: Error {
        case noPushId
    }

    @objc private func refresh() {
        if initialPromise == nil {
            refreshControl.beginRefreshing()
        }

        firstly { () -> Promise<RateLimitResponse> in
            if let initialPromise {
                self.initialPromise = nil
                return initialPromise
            } else {
                return Self.newPromise()
            }
        }.done { [form, rateLimitDidChange] response in
            guard let section = form.sectionBy(tag: "rateLimits") else {
                return
            }

            Current.Log.debug("updated rate limits: \(response)")

            section.footer = HeaderFooterView(
                title: L10n.SettingsDetails.Notifications.RateLimits.footerWithParam(response.rateLimits.maximum)
            )

            UIView.performWithoutAnimation {
                section.removeAll()

                section
                    <<< response.rateLimits.row(for: \.attempts)
                    <<< response.rateLimits.row(for: \.successful)
                    <<< response.rateLimits.row(for: \.errors)
                    <<< response.rateLimits.row(for: \.total)
                    <<< response.rateLimits.row(for: \.resetsAt)
            }

            rateLimitDidChange(response)
        }.done { [weak self] _ in
            self?.updateTimer()
        }.ensure { [refreshControl] in
            refreshControl.endRefreshing()
        }.catch { [form] error in
            Current.Log.error("couldn't load rate limit: \(error)")
            guard let section = form.sectionBy(tag: "rateLimits") else {
                return
            }

            section.removeAll()

            section <<< ButtonRow {
                $0.title = L10n.retryLabel
                $0.onCellSelection { [weak self] _, _ in
                    self?.refresh()
                }
            }
        }
    }

    @objc func updateTimer() {
        var calendar = Calendar.current
        calendar.timeZone = utc

        guard let startOfNextDay = calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTimePreservingSmallerComponents
        ) else {
            return
        }
        guard let row = form.rowBy(tag: "resetsIn") as? LabelRow else { return }

        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.hour, .minute, .second]

        row.value = formatter.string(from: Date(), to: startOfNextDay)
        row.updateCell()
    }
}

public extension RateLimitResponse.RateLimits {
    func row(for keyPath: KeyPath<Self, Int>) -> BaseRow {
        LabelRow {
            $0.value = NumberFormatter.localizedString(
                from: NSNumber(value: self[keyPath: keyPath]),
                number: .none
            )
            $0.title = { () -> String in
                switch keyPath {
                case \.attempts:
                    return L10n.SettingsDetails.Notifications.RateLimits.attempts
                case \.successful:
                    return L10n.SettingsDetails.Notifications.RateLimits.delivered
                case \.errors:
                    return L10n.SettingsDetails.Notifications.RateLimits.errors
                case \.total:
                    return L10n.SettingsDetails.Notifications.RateLimits.total
                case \.maximum:
                    return ""
                default:
                    fatalError("missing key: \(keyPath)")
                }
            }()
        }
    }

    func row(for keyPath: KeyPath<Self, Date>) -> BaseRow {
        LabelRow { row in
            row.value = DateFormatter.localizedString(
                from: self[keyPath: keyPath],
                dateStyle: .none,
                timeStyle: .medium
            )

            switch keyPath {
            case \.resetsAt:
                row.title = L10n.SettingsDetails.Notifications.RateLimits.resetsIn
                row.tag = "resetsIn"
            default:
                fatalError("missing key: \(keyPath)")
            }
        }
    }
}
