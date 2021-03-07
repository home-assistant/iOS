import Eureka
import HAKit
import Shared

public final class WebSocketStatusRow: Row<LabelCellOf<HAConnectionState>>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)

        title = L10n.Settings.ConnectionSection.Websocket.title
        displayValueFor = { $0.flatMap { Self.message(for: $0, verbose: false) } }
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

    @objc private func stateDidChange() {
        value = Current.apiConnection.state
        updateCell()
    }

    override public func updateCell() {
        super.updateCell()

        lastAlertController?.message = value.flatMap { Self.message(for: $0, verbose: true) }
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

    private static func message(for state: HAConnectionState, verbose: Bool) -> String {
        let wsL10n = L10n.Settings.ConnectionSection.Websocket.self

        switch state {
        case .connecting: return wsL10n.Status.connecting
        case .authenticating: return wsL10n.Status.authenticating
        case let .disconnected(reason):
            let nonVerboseString = wsL10n.Status.Disconnected.title
            let verboseString: String

            switch reason {
            case let .waitingToReconnect(lastError: error, atLatest: atLatest, retryCount: count):
                var components = [String]()

                if let error = error {
                    components.append(wsL10n.Status.Disconnected.error(error.localizedDescription))
                }

                components.append(wsL10n.Status.Disconnected.retryCount(count))
                components.append(wsL10n.Status.Disconnected.nextRetry(
                    DateFormatter.localizedString(from: atLatest, dateStyle: .none, timeStyle: .medium)
                ))

                verboseString = components.joined(separator: "\n\n")
            case .disconnected:
                verboseString = nonVerboseString
            }

            return verbose ? verboseString : nonVerboseString
        case .ready: return L10n.Settings.ConnectionSection.Websocket.Status.connected
        }
    }

    private weak var lastAlertController: UIAlertController?
    private func presentAlert() {
        guard let value = value else { return }

        let alert = UIAlertController(
            title: title,
            message: Self.message(for: value, verbose: true),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.copyLabel, style: .default, handler: { _ in
            UIPasteboard.general.string = Self.message(for: value, verbose: true)
        }))
        alert.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: nil))

        cell.formViewController()?.present(alert, animated: true, completion: nil)
        deselect(animated: true)
        lastAlertController = alert
    }
}
