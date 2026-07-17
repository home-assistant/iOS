import Shared
import SwiftUI
import UIKit

// MARK: - Empty State

extension WebViewController {
    func emptyStateStyle(for connectionState: FrontEndConnectionState) -> WebViewEmptyStateStyle {
        switch connectionState {
        case .authInvalid:
            .unauthenticated
        case .connected, .loaded, .disconnected, .unknown:
            .disconnected
        }
    }

    /// Shows the disconnected/unauthenticated empty state as a SwiftUI overlay in `HomeAssistantView` (via
    /// `overlayState`) rather than an alpha-animated subview, so app-level sheets can float over it.
    func showEmptyState() {
        withAnimation(DesignSystem.Animation.easeInOutFaster) {
            overlayState?.emptyState = makeEmptyStateContent()
        }
        if connectionState == .disconnected || connectionState == .unknown {
            reconnectManager?.start { [weak self] in
                self?.recoverDisconnectedFrontend()
            }
        } else {
            reconnectManager?.stop()
        }
    }

    @objc func hideEmptyState() {
        withAnimation(DesignSystem.Animation.easeInOutFaster) {
            overlayState?.emptyState = nil
        }
        reconnectManager?.stop()
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

    func retryClearingFrontendCache() {
        Current.Log.info("Resetting frontend cache for \(server.identifier) before empty-state retry")
        overlayState?.isLoading = true
        withAnimation(DesignSystem.Animation.easeInOutFaster) {
            overlayState?.emptyState = nil
        }
        Current.websiteDataStoreHandler
            .cleanCache(dataTypes: WebsiteDataStoreHandlerImpl.frontendAssetDataTypes) { [weak self] in
                self?.recoverDisconnectedFrontend()
            }
    }

    func recoverDisconnectedFrontend() {
        if let resetFrontendAction {
            resetFrontendAction()
        } else {
            hideEmptyState()
            refresh()
        }
    }

    private func makeEmptyStateContent() -> WebFrontendOverlayState.EmptyStateContent {
        WebFrontendOverlayState.EmptyStateContent(
            style: emptyStateStyle(for: connectionState),
            server: server,
            showsErrorDetailsButton: shouldShowErrorDetailsButton,
            availableReauthURLTypes: availableReauthURLTypes(for: server),
            retryAction: { [weak self] in
                self?.retryClearingFrontendCache()
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
