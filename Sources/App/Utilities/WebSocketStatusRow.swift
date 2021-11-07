import Eureka
import HAKit
import Shared

public final class WebSocketStatusCell: Cell<HAConnectionState>, CellType {
    public let activityIndicator = with(UIActivityIndicatorView()) {
        if #available(iOS 13, *) {
            $0.style = .medium
        } else {
            $0.style = .gray
        }
    }

    override public func update() {
        super.update()

        switch (row as? WebSocketStatusRow)?.displayStyle ?? .default {
        case .default, .alert:
            activityIndicator.removeFromSuperview()
        case .loading:
            if activityIndicator.superview == nil {
                contentView.addSubview(activityIndicator)
                activityIndicator.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    // not constraining to top/bottom because that causes the cell to shrink compared to a LabelRow
                    activityIndicator.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
                    activityIndicator.centerYAnchor.constraint(equalTo: contentView.layoutMarginsGuide.centerYAnchor),
                ])
            }
            activityIndicator.startAnimating()
        }
    }
}

public final class WebSocketStatusRow: Row<WebSocketStatusCell>, RowType {
    public enum DisplayStyle {
        case `default`
        case loading
        case alert

        func title(for state: HAConnectionState) -> String? {
            switch self {
            case .default, .alert: return L10n.Settings.ConnectionSection.Websocket.title
            case .loading: return nil
            }
        }

        func message(for state: HAConnectionState) -> String? {
            switch state {
            case .connecting: return L10n.Settings.ConnectionSection.Websocket.Status.connecting
            case .authenticating: return L10n.Settings.ConnectionSection.Websocket.Status.authenticating
            case let .disconnected(reason):
                let nonVerboseString = L10n.Settings.ConnectionSection.Websocket.Status.Disconnected.title
                let verboseString: String

                switch reason {
                case let .waitingToReconnect(lastError: error, atLatest: atLatest, retryCount: count):
                    var components = [String]()

                    if let error = error {
                        components.append(L10n.Settings.ConnectionSection.Websocket.Status.Disconnected.error(
                            error.localizedDescription
                        ))
                    }

                    components.append(L10n.Settings.ConnectionSection.Websocket.Status.Disconnected.retryCount(count))
                    components.append(L10n.Settings.ConnectionSection.Websocket.Status.Disconnected.nextRetry(
                        DateFormatter.localizedString(from: atLatest, dateStyle: .none, timeStyle: .medium)
                    ))

                    verboseString = components.joined(separator: "\n\n")
                case .disconnected:
                    verboseString = nonVerboseString
                }

                switch self {
                case .default, .loading: return nonVerboseString
                case .alert: return verboseString
                }
            case .ready:
                switch self {
                case .default, .alert: return L10n.Settings.ConnectionSection.Websocket.Status.connected
                case .loading: return nil
                }
            }
        }
    }

    public var displayStyle: DisplayStyle = .default {
        didSet {
            updateCell()
        }
    }

    public required init(tag: String?) {
        super.init(tag: tag)

        displayValueFor = { [weak self] value in
            if let value = value, let self = self {
                return self.displayStyle.message(for: value)
            } else {
                return nil
            }
        }
        onCellSelection { [weak self] _, _ in
            self?.presentAlert()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(stateDidChange),
            name: HAConnectionState.didTransitionToStateNotification,
            object: nil
        )

        stateDidChange()
    }

    public var connection: HAConnection? {
        didSet {
            stateDidChange()
        }
    }

    @objc private func stateDidChange() {
        value = connection?.state
        updateCell()
    }

    override public func updateCell() {
        super.updateCell()

        cell.textLabel?.text = value.flatMap { displayStyle.title(for: $0) }
        lastAlertController?.message = value.flatMap { DisplayStyle.alert.message(for: $0) }

        cell.selectionStyle = .default

        cell.accessibilityTraits.insert(.button)

        switch value {
        case .disconnected(reason: _):
            let icon = MaterialDesignIcons.informationOutlineIcon.image(
                ofSize: CGSize(width: 24, height: 24),
                color: Constants.tintColor
            )
            cell.accessoryView = UIImageView(image: icon)
        default:
            cell.accessoryView = nil
        }
    }

    private weak var lastAlertController: UIAlertController?
    private func presentAlert() {
        guard let value = value else { return }

        let alert = UIAlertController(
            title: DisplayStyle.alert.title(for: value),
            message: DisplayStyle.alert.message(for: value),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.copyLabel, style: .default, handler: { _ in
            UIPasteboard.general.string = DisplayStyle.alert.message(for: value)
        }))
        alert.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: nil))

        cell.formViewController()?.present(alert, animated: true, completion: nil)
        deselect(animated: true)
        lastAlertController = alert
    }
}
