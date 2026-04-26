import Shared
import SwiftUI
import UIKit

final class WebViewEmptyStateWrapperView: UIView {
    private let hostingController: UIHostingController<WebViewEmptyStateView>
    private let server: Server
    private let retryAction: (() -> Void)?
    private let settingsAction: (() -> Void)?
    private let errorDetailsAction: (() -> Void)?
    private let reauthAction: ((ConnectionInfo.URLType) -> Void)?
    private let recoveredServerReauthAction: (
        (ConnectionInfo.URLType, @escaping (Swift.Result<Void, Error>) -> Void)
            -> Void
    )?
    private let serverSelectionAction: ((Server) -> Void)?
    private let dismissAction: (() -> Void)?
    private(set) var style: WebViewEmptyStateStyle
    private(set) var showsErrorDetailsButton: Bool

    init(
        style: WebViewEmptyStateStyle = .disconnected,
        server: Server,
        showsErrorDetailsButton: Bool = false,
        retryAction: (() -> Void)? = nil,
        settingsAction: (() -> Void)? = nil,
        errorDetailsAction: (() -> Void)? = nil,
        reauthAction: ((ConnectionInfo.URLType) -> Void)? = nil,
        recoveredServerReauthAction: (
            (ConnectionInfo.URLType, @escaping (Swift.Result<Void, Error>) -> Void) -> Void
        )? = nil,
        serverSelectionAction: ((Server) -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.style = style
        self.server = server
        self.showsErrorDetailsButton = showsErrorDetailsButton
        self.retryAction = retryAction
        self.settingsAction = settingsAction
        self.errorDetailsAction = errorDetailsAction
        self.reauthAction = reauthAction
        self.recoveredServerReauthAction = recoveredServerReauthAction
        self.serverSelectionAction = serverSelectionAction
        self.dismissAction = dismissAction
        let swiftUIView = WebViewEmptyStateView(
            style: style,
            server: server,
            showsErrorDetailsButton: showsErrorDetailsButton,
            availableReauthURLTypes: Self.availableReauthURLTypes(for: server),
            retryAction: retryAction,
            settingsAction: settingsAction,
            errorDetailsAction: errorDetailsAction,
            reauthAction: reauthAction,
            recoveredServerReauthAction: recoveredServerReauthAction,
            serverSelectionAction: serverSelectionAction,
            dismissAction: dismissAction
        )
        self.hostingController = UIHostingController(rootView: swiftUIView)
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        backgroundColor = .clear
    }

    func update(style: WebViewEmptyStateStyle, showsErrorDetailsButton: Bool) {
        guard self.style != style || self.showsErrorDetailsButton != showsErrorDetailsButton else { return }
        self.style = style
        self.showsErrorDetailsButton = showsErrorDetailsButton
        hostingController.rootView = WebViewEmptyStateView(
            style: style,
            server: server,
            showsErrorDetailsButton: showsErrorDetailsButton,
            availableReauthURLTypes: Self.availableReauthURLTypes(for: server),
            retryAction: retryAction,
            settingsAction: settingsAction,
            errorDetailsAction: errorDetailsAction,
            reauthAction: reauthAction,
            recoveredServerReauthAction: recoveredServerReauthAction,
            serverSelectionAction: serverSelectionAction,
            dismissAction: dismissAction
        )
    }

    /// Returns available URL types for re-authentication, ordered by preference: remote UI > external > internal.
    private static func availableReauthURLTypes(for server: Server) -> [ConnectionInfo.URLType] {
        let preferenceOrder: [ConnectionInfo.URLType] = [.remoteUI, .external, .internal]
        return preferenceOrder.filter { server.info.connection.address(for: $0) != nil }
    }
}
