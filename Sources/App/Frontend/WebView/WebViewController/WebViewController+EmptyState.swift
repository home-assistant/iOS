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
        upgradeEmptyStateForFlightIfNeeded()
    }

    /// Swaps the disconnected empty state for the in-flight variant (and greets) when flight
    /// detection confirms the user is on a plane. Detection is async (Wi-Fi SSID + one-shot GPS),
    /// so the regular disconnected state shows first and upgrades in place.
    private func upgradeEmptyStateForFlightIfNeeded() {
        guard Current.settingsStore.flightGreetingsEnabled,
              emptyStateStyle(for: connectionState) == .disconnected else { return }
        Task { @MainActor [weak self] in
            guard await FlightGreetingManager.shared.isCurrentlyFlying() else { return }
            guard let self, overlayState?.emptyState?.style == .disconnected else { return }
            withAnimation(DesignSystem.Animation.easeInOutFaster) {
                self.overlayState?.emptyState = self.makeEmptyStateContent(style: .inFlight)
            }
            FlightGreetingManager.shared.presentGreetingToastIfAllowed()
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

    private func makeEmptyStateContent(
        style: WebViewEmptyStateStyle? = nil
    ) -> WebFrontendOverlayState.EmptyStateContent {
        WebFrontendOverlayState.EmptyStateContent(
            style: style ?? emptyStateStyle(for: connectionState),
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
