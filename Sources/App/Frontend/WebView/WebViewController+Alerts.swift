import Shared
import SwiftUI
import UIKit

enum BannerDuration {
    case seconds(TimeInterval)
    case forever
}

extension BannerDuration: Equatable {
    static func == (lhs: BannerDuration, rhs: BannerDuration) -> Bool {
        switch (lhs, rhs) {
        case (.forever, .forever):
            return true
        case let (.seconds(lhsDuration), .seconds(rhsDuration)):
            return lhsDuration == rhsDuration
        default:
            return false
        }
    }
}

enum BannerDimming: Equatable {
    case none
    case gray(interactive: Bool)

    var isInteractive: Bool {
        switch self {
        case .none:
            return false
        case let .gray(interactive):
            return interactive
        }
    }

    var color: UIColor {
        switch self {
        case .none:
            return .clear
        case .gray:
            return UIColor.black.withAlphaComponent(0.35)
        }
    }
}

struct BannerStyle {
    let backgroundColor: UIColor
    let foregroundColor: UIColor

    static func card(backgroundColor: UIColor, foregroundColor: UIColor) -> Self {
        .init(backgroundColor: backgroundColor, foregroundColor: foregroundColor)
    }

    static let warning = Self(
        backgroundColor: UIColor(red: 1.000, green: 0.596, blue: 0.000, alpha: 1.0),
        foregroundColor: .white
    )
}

extension BannerStyle: Equatable {
    static func == (lhs: BannerStyle, rhs: BannerStyle) -> Bool {
        lhs.backgroundColor.isEqual(rhs.backgroundColor)
            && lhs.foregroundColor.isEqual(rhs.foregroundColor)
    }
}

struct BannerAction {
    let title: String?
    let image: UIImage?
    let tintColor: UIColor
    let accessibilityLabel: String?
    let dismissOnTap: Bool
    let handler: () -> Void

    init(
        title: String? = nil,
        image: UIImage? = nil,
        tintColor: UIColor,
        accessibilityLabel: String? = nil,
        dismissOnTap: Bool = true,
        handler: @escaping () -> Void
    ) {
        self.title = title
        self.image = image
        self.tintColor = tintColor
        self.accessibilityLabel = accessibilityLabel
        self.dismissOnTap = dismissOnTap
        self.handler = handler
    }
}

struct BannerRequest {
    let id: String
    let title: String?
    let message: String?
    let duration: BannerDuration
    let dimming: BannerDimming
    let style: BannerStyle
    let action: BannerAction?
    let onDismiss: (() -> Void)?
    let dimmingAccessibilityLabel: String?

    init(
        id: String = UUID().uuidString,
        title: String?,
        message: String?,
        duration: BannerDuration,
        dimming: BannerDimming,
        style: BannerStyle,
        action: BannerAction? = nil,
        onDismiss: (() -> Void)? = nil,
        dimmingAccessibilityLabel: String? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.duration = duration
        self.dimming = dimming
        self.style = style
        self.action = action
        self.onDismiss = onDismiss
        self.dimmingAccessibilityLabel = dimmingAccessibilityLabel
    }

    func matchesPresentation(of other: BannerRequest) -> Bool {
        id == other.id || (
            title == other.title
                && message == other.message
                && duration == other.duration
                && dimming == other.dimming
                && style == other.style
                && action.matchesPresentation(of: other.action)
        )
    }
}

private extension BannerAction? {
    func matchesPresentation(of other: BannerAction?) -> Bool {
        switch (self, other) {
        case (.none, .none):
            return true
        case let (.some(lhs), .some(rhs)):
            return lhs.title == rhs.title
                && lhs.accessibilityLabel == rhs.accessibilityLabel
                && lhs.dismissOnTap == rhs.dismissOnTap
                && lhs.tintColor.isEqual(rhs.tintColor)
                && (lhs.image != nil) == (rhs.image != nil)
        default:
            return false
        }
    }
}

protocol BannerPresenter: AnyObject {
    func show(on viewController: UIViewController, request: BannerRequest)
    func hide(id: String)
}

private enum BannerDismissReason {
    case action
    case backgroundTap
    case programmatic
}

final class DefaultBannerPresenter: BannerPresenter {
    private weak var currentOverlay: BannerOverlayView?
    private var currentRequest: BannerRequest?
    private var autoDismissWorkItem: DispatchWorkItem?

    func show(on viewController: UIViewController, request: BannerRequest) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let currentRequest, currentOverlay != nil, currentRequest.matchesPresentation(of: request) {
                return
            }

            dismissCurrent(animated: false)

            viewController.loadViewIfNeeded()

            let overlay = BannerOverlayView(request: request)
            overlay.translatesAutoresizingMaskIntoConstraints = false
            overlay.onDismissRequested = { [weak self, weak overlay] reason in
                guard let self, let overlay, currentOverlay === overlay else { return }
                dismissCurrent(animated: true, after: {
                    if case .action = reason {
                        request.action?.handler()
                    }
                })
            }
            overlay.onActionRequested = { [weak self, weak overlay] in
                guard let self, let overlay, currentOverlay === overlay else { return }
                guard let action = request.action else { return }

                if action.dismissOnTap {
                    dismissCurrent(animated: true, after: action.handler)
                } else {
                    action.handler()
                }
            }

            viewController.view.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.topAnchor.constraint(equalTo: viewController.view.topAnchor),
                overlay.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
                overlay.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor),
            ])

            currentOverlay = overlay
            currentRequest = request
            scheduleAutoDismiss(for: request)
            overlay.present()
        }
    }

    func hide(id: String) {
        DispatchQueue.main.async { [weak self] in
            guard self?.currentRequest?.id == id else { return }
            self?.dismissCurrent(animated: true)
        }
    }

    private func scheduleAutoDismiss(for request: BannerRequest) {
        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil

        guard case let .seconds(duration) = request.duration else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.hide(id: request.id)
        }
        autoDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    private func dismissCurrent(animated: Bool, after: (() -> Void)? = nil) {
        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil

        guard let overlay = currentOverlay else {
            currentRequest = nil
            after?()
            return
        }

        let request = currentRequest
        currentOverlay = nil
        currentRequest = nil

        overlay.dismiss(animated: animated) {
            request?.onDismiss?()
            after?()
        }
    }
}

private final class BannerOverlayView: UIView {
    private let request: BannerRequest
    private let backgroundButton = UIButton(type: .custom)
    private let bannerView = UIView()
    private let contentStack = UIStackView()
    private let labelsStack = UIStackView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let actionButton = UIButton(type: .system)

    var onDismissRequested: ((BannerDismissReason) -> Void)?
    var onActionRequested: (() -> Void)?

    init(request: BannerRequest) {
        self.request = request
        super.init(frame: .zero)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if request.dimming.isInteractive {
            return super.point(inside: point, with: event)
        }

        let bannerPoint = convert(point, to: bannerView)
        return bannerView.point(inside: bannerPoint, with: event)
    }

    func present() {
        bannerView.transform = .init(translationX: 0, y: 120)
        backgroundButton.alpha = 0

        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
            self.bannerView.transform = .identity
            self.backgroundButton.alpha = self.request.dimming == .none ? 0 : 1
        }
    }

    func dismiss(animated: Bool, completion: @escaping () -> Void) {
        let animations = {
            self.bannerView.transform = .init(translationX: 0, y: 120)
            self.backgroundButton.alpha = 0
        }

        let finished: (Bool) -> Void = { _ in
            self.removeFromSuperview()
            completion()
        }

        if animated {
            UIView.animate(
                withDuration: 0.2,
                delay: 0,
                options: [.curveEaseIn],
                animations: animations,
                completion: finished
            )
        } else {
            animations()
            finished(true)
        }
    }

    private func setupView() {
        backgroundColor = .clear

        backgroundButton.translatesAutoresizingMaskIntoConstraints = false
        backgroundButton.backgroundColor = request.dimming.color
        backgroundButton.isAccessibilityElement = request.dimming.isInteractive
        backgroundButton.accessibilityLabel = request.dimmingAccessibilityLabel
        backgroundButton.addTarget(self, action: #selector(backgroundTapped), for: .touchUpInside)
        addSubview(backgroundButton)

        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.backgroundColor = request.style.backgroundColor
        bannerView.layer.cornerRadius = DesignSystem.CornerRadius.two
        bannerView.layer.cornerCurve = .continuous
        bannerView.layer.shadowColor = UIColor.black.cgColor
        bannerView.layer.shadowOpacity = 0.18
        bannerView.layer.shadowRadius = 18
        bannerView.layer.shadowOffset = CGSize(width: 0, height: 6)
        bannerView.accessibilityIdentifier = request.id
        addSubview(bannerView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = DesignSystem.Spaces.oneAndHalf
        bannerView.addSubview(contentStack)

        labelsStack.axis = .vertical
        labelsStack.alignment = .fill
        labelsStack.spacing = DesignSystem.Spaces.half
        contentStack.addArrangedSubview(labelsStack)

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = request.style.foregroundColor
        titleLabel.numberOfLines = 0
        titleLabel.text = request.title
        titleLabel.isHidden = request.title == nil
        labelsStack.addArrangedSubview(titleLabel)

        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.textColor = request.style.foregroundColor
        messageLabel.numberOfLines = 0
        messageLabel.text = request.message
        messageLabel.isHidden = request.message == nil
        labelsStack.addArrangedSubview(messageLabel)

        actionButton.setContentHuggingPriority(.required, for: .horizontal)
        actionButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        actionButton.tintColor = request.action?.tintColor
        actionButton.accessibilityLabel = request.action?.accessibilityLabel
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        configureActionButton()
        if request.action != nil {
            contentStack.addArrangedSubview(actionButton)
        }

        NSLayoutConstraint.activate([
            backgroundButton.topAnchor.constraint(equalTo: topAnchor),
            backgroundButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundButton.bottomAnchor.constraint(equalTo: bottomAnchor),

            bannerView.leadingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.leadingAnchor,
                constant: DesignSystem.Spaces.two
            ),
            bannerView.trailingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.trailingAnchor,
                constant: -DesignSystem.Spaces.two
            ),
            bannerView.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor,
                constant: -DesignSystem.Spaces.two
            ),

            contentStack.topAnchor.constraint(equalTo: bannerView.topAnchor, constant: DesignSystem.Spaces.oneAndHalf),
            contentStack.leadingAnchor.constraint(equalTo: bannerView.leadingAnchor, constant: DesignSystem.Spaces.two),
            contentStack.trailingAnchor.constraint(
                equalTo: bannerView.trailingAnchor,
                constant: -DesignSystem.Spaces.two
            ),
            contentStack.bottomAnchor.constraint(
                equalTo: bannerView.bottomAnchor,
                constant: -DesignSystem.Spaces.oneAndHalf
            ),
        ])
    }

    private func configureActionButton() {
        guard let action = request.action else {
            actionButton.isHidden = true
            return
        }

        actionButton.isHidden = false
        actionButton.tintColor = action.tintColor

        if let image = action.image {
            actionButton.setImage(image.withRenderingMode(.alwaysTemplate), for: .normal)
        }

        if let title = action.title {
            actionButton.setTitle(title, for: .normal)
            actionButton.setTitleColor(action.tintColor, for: .normal)
            actionButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        } else {
            actionButton.setTitle(nil, for: .normal)
        }

        actionButton.contentEdgeInsets = .init(
            top: DesignSystem.Spaces.half,
            left: DesignSystem.Spaces.half,
            bottom: DesignSystem.Spaces.half,
            right: DesignSystem.Spaces.half
        )
    }

    @objc private func backgroundTapped() {
        guard request.dimming.isInteractive else { return }
        onDismissRequested?(.backgroundTap)
    }

    @objc private func actionTapped() {
        onActionRequested?()
    }
}

// MARK: - Alerts & Message Presentation

extension WebViewController {
    func show(alert: ServerAlert) {
        Current.Log.info("showing alert \(alert)")
        showBanner(request: .init(
            id: alert.id,
            title: nil,
            message: alert.message,
            duration: .forever,
            dimming: .gray(interactive: true),
            style: .warning,
            action: .init(
                title: L10n.openLabel,
                tintColor: .white,
                handler: {
                    URLOpener.shared.open(alert.url, options: [:], completionHandler: nil)
                }
            ),
            onDismiss: {
                Current.serverAlerter.markHandled(alert: alert)
            },
            dimmingAccessibilityLabel: L10n.cancelLabel
        ))
    }

    func showSwiftMessage(error: Error, duration: TimeInterval = 15) {
        Current.Log.error(error)
        showBanner(request: .init(
            title: L10n.Connection.Error.genericTitle,
            message: nil,
            duration: .seconds(duration),
            dimming: .none,
            style: .card(
                backgroundColor: .secondarySystemBackground,
                foregroundColor: .label
            ),
            action: .init(
                image: MaterialDesignIcons.helpCircleIcon.image(
                    ofSize: .init(width: 35, height: 35),
                    color: .haPrimary
                ),
                tintColor: .haPrimary,
                accessibilityLabel: L10n.helpLabel,
                handler: { [weak self] in
                    guard let self else { return }
                    presentOverlayController(
                        controller: UIHostingController(rootView: ConnectionErrorDetailsView(
                            server: server,
                            error: error
                        )),
                        animated: true
                    )
                }
            )
        ))
    }

    func showReAuthPopup(serverId: String, code: Int) {
        guard serverId == server.identifier.rawValue else {
            return
        }

        // Avoid retrying from Home Assistant UI since this is a dead end
        load(request: URLRequest(url: URL(string: "about:blank")!))
        showEmptyState()
        showBanner(request: .init(
            id: "reauth-\(serverId)",
            title: L10n.Unauthenticated.Message.title,
            message: L10n.Unauthenticated.Message.body,
            duration: .forever,
            dimming: .gray(interactive: true),
            style: .warning,
            action: .init(
                image: MaterialDesignIcons.cogIcon.image(
                    ofSize: CGSize(width: 24, height: 24),
                    color: .haPrimary
                ),
                tintColor: .haPrimary,
                accessibilityLabel: L10n.ConnectionError.OpenSettings.title,
                dismissOnTap: false,
                handler: { [weak self] in
                    self?.showSettingsViewController()
                }
            ),
            dimmingAccessibilityLabel: L10n.cancelLabel
        ))
    }

    func showActionAutomationEditorNotAvailable() {
        let alert = UIAlertController(
            title: L10n.Alerts.ActionAutomationEditor.Unavailable.title,
            message: L10n.Alerts.ActionAutomationEditor.Unavailable.body,
            preferredStyle: .alert
        )
        alert.addAction(.init(title: L10n.okLabel, style: .default))
        present(alert, animated: true)
    }

    func openDebug() {
        let controller = UIHostingController(rootView: AnyView(
            NavigationView {
                VStack {
                    HStack(spacing: DesignSystem.Spaces.half) {
                        Text(verbatim: L10n.Settings.Debugging.ShakeDisclaimerOptional.title)
                        Toggle(isOn: .init(get: {
                            Current.settingsStore.gestures[.shake] == .openDebug
                        }, set: { newValue in
                            Current.settingsStore.gestures[.shake] = newValue ? .openDebug : HAGestureAction.none
                        }), label: { EmptyView() })
                    }
                    .padding()
                    .background(Color.haPrimary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf))
                    .padding(DesignSystem.Spaces.one)
                    DebugView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                CloseButton { [weak self] in
                                    self?.dismissOverlayController(animated: true, completion: nil)
                                }
                            }
                        }
                }
            }
        ))
        presentOverlayController(controller: controller, animated: true)
    }
}
