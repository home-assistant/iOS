import Shared
import SwiftUI
import UIKit

// MARK: - Empty State

extension WebViewController {
    func emptyStateStyle(for connectionState: FrontEndConnectionState) -> WebViewEmptyStateStyle {
        switch connectionState {
        case .authInvalid:
            .unauthenticated
        case .connected, .disconnected, .unknown:
            .disconnected
        }
    }

    /// Shows the disconnected/unauthenticated empty state as a SwiftUI overlay in `HomeAssistantView` (via
    /// `overlayState`) rather than an alpha-animated subview, so app-level sheets can float over it.
    func showEmptyState() {
        overlayState?.emptyState = makeEmptyStateContent()
    }

    @objc func hideEmptyState() {
        overlayState?.emptyState = nil
    }

    var shouldShowErrorDetailsButton: Bool {
        connectionState == .disconnected && latestLoadError != nil
    }

    func presentLatestLoadErrorDetails() {
        guard let latestLoadError else { return }
        presentOverlayController(
            controller: UIHostingController(rootView: ConnectionErrorDetailsView(
                server: server,
                error: latestLoadError
            )),
            animated: true
        )
    }

    // To avoid keeping the empty state on screen when user is disconnected in background
    // due to inactivity, we reset the empty state timer
    @objc func resetEmptyStateTimerWithLatestConnectedState() {
        let state: FrontEndConnectionState = if connectionState == .authInvalid {
            .authInvalid
        } else {
            isConnected ? .connected : .disconnected
        }
        updateFrontendConnectionState(state: state.rawValue)
    }

    func emptyStateObservations() {
        // Hide empty state when enter background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hideEmptyState),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        // Show empty state again if after entering foreground it is not connected
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetEmptyStateTimerWithLatestConnectedState),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    func removeEmptyStateObservations() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    private func makeEmptyStateContent() -> WebFrontendOverlayState.EmptyStateContent {
        WebFrontendOverlayState.EmptyStateContent(
            style: emptyStateStyle(for: connectionState),
            server: server,
            showsErrorDetailsButton: shouldShowErrorDetailsButton,
            availableReauthURLTypes: availableReauthURLTypes(for: server),
            retryAction: { [weak self] in
                self?.hideEmptyState()
                self?.refresh()
            },
            settingsAction: { [weak self] in self?.showSettingsViewController() },
            errorDetailsAction: { [weak self] in self?.presentLatestLoadErrorDetails() },
            reauthAction: { [weak self] urlType in self?.performReauthentication(using: urlType) },
            dismissAction: { [weak self] in self?.hideEmptyState() }
        )
    }

    /// Available URL types for re-authentication, ordered by preference: remote UI > external > internal.
    private func availableReauthURLTypes(for server: Server) -> [ConnectionInfo.URLType] {
        [.remoteUI, .external, .internal].filter { server.info.connection.address(for: $0) != nil }
    }
}
