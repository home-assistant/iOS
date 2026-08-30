import Alamofire
import Shared
import SwiftUI
import UIKit

// MARK: - Empty State

extension WebViewController {
    func emptyStateStyle(for connectionState: FrontEndConnectionState) -> WebViewEmptyStateStyle {
        // A deliberate log out lands in the same authentication-less state as a revoked token, so it is
        // resolved first: the copy has to read as "log back in", not "your session expired".
        if didLogOut {
            return .loggedOut
        }
        switch connectionState {
        case .authInvalid:
            return .unauthenticated
        case .connected, .loaded, .disconnected, .unknown:
            return .disconnected
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
    /// detection confirms the user is on a plane. Detection is async (Wi-Fi SSID, cabin pressure,
    /// then GPS, which offline can take tens of seconds), so the regular disconnected state shows
    /// first and upgrades in place.
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

    /// Arms the grace timer that shows the empty state unless a `connected`/`loaded` frontend state
    /// arrives first. The timer clears itself as it fires so a later failure can arm a fresh one.
    func scheduleEmptyStateAfterGracePeriod() {
        emptyStateTimer?.invalidate()
        let timeout = TimeInterval(Current.settingsStore.webViewEmptyStateTimeout)
        emptyStateTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.emptyStateTimer = nil
            self?.showEmptyState()
        }
    }

    /// The frontend asks the app for an access token before it can connect to the server, and keeps
    /// retrying while that fails. A failure there produces neither a navigation error nor a frontend
    /// connection state — the page itself loaded fine, it just can't authenticate — so nothing would
    /// ever take the stand-by loader down and the app appears to load forever. Treat it like a failed
    /// load instead: keep the error for the details screen and fall back to the empty state.
    func handleExternalAuthFailure(error: Error) {
        guard !connectionState.isReadyForDisplay else { return }
        latestLoadError = Self.presentableExternalAuthError(for: error)

        // The frontend retries in a tight loop, so only the first failure arms the grace period; an
        // empty state that is already up must not be pushed back by the retries behind it.
        guard emptyStateTimer == nil, overlayState?.emptyState == nil else { return }

        Current.Log.error("Frontend could not be authenticated, showing empty state: \(error)")
        let resolvedState: FrontEndConnectionState = connectionState == .authInvalid ? .authInvalid : .disconnected
        connectionState = resolvedState
        overlayState?.connectionState = resolvedState
        scheduleEmptyStateAfterGracePeriod()
    }

    /// Unwraps Alamofire's session-task wrapper so the error details screen shows the `URLError` the
    /// user can act on (offline, local network blocked, TLS) rather than the transport wrapper, which
    /// carries no failing URL and no actionable domain/code.
    static func presentableExternalAuthError(for error: Error) -> Error {
        (error.asAFError?.underlyingError as? URLError) ?? error
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
            availableReauthURLTypes: server.info.connection.availableAuthenticationURLTypes,
            retryAction: { [weak self] in
                self?.retryClearingFrontendCache()
            },
            settingsAction: { [weak self] in self?.showSettingsViewController() },
            errorDetailsAction: { [weak self] in self?.presentLatestLoadErrorDetails() },
            reauthAction: { [weak self] urlType in self?.performReauthentication(using: urlType) },
            dismissAction: { [weak self] in self?.hideEmptyState() }
        )
    }
}
