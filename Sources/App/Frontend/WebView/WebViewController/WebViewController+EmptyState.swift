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
        // A certificate problem is a dead end for retries and re-authentication alike: the handshake never
        // completes, so whatever the connection state says, the way back in is importing a certificate.
        if let clientCertificateIssue {
            return WebViewEmptyStateStyle(clientCertificateIssue: clientCertificateIssue)
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
    ///
    /// While the scene is not active the disconnected variant is held back instead: nobody can see it, and
    /// the usual reason the frontend is disconnected is the backgrounding itself (its socket died, or the
    /// web content process was reclaimed, while the scene was away), which a frontend that is on screen
    /// again recovers from in a moment. `handleSceneDidActivate()` gives it the grace period for that, so
    /// the user coming back sees the frontend or the loader rather than an error that is already out of
    /// date. Authentication and certificate problems are shown regardless: time does not fix those, and
    /// the frontend has nothing to retry.
    func showEmptyState() {
        if !isSceneActive(frontendWindowScene), emptyStateStyle(for: connectionState) == .disconnected {
            Current.Log.info("Deferring the disconnected empty state until the scene is active")
            isEmptyStateDeferredUntilActive = true
            return
        }
        isEmptyStateDeferredUntilActive = false
        withAnimation(DesignSystem.Animation.easeInOutFaster) {
            overlayState?.emptyState = makeEmptyStateContent()
        }
        // Automatic reconnection only makes sense for a connection that might come back on its own; a
        // missing or refused certificate fails the same way every time until the user imports one.
        if connectionState == .disconnected || connectionState == .unknown, clientCertificateIssue == nil {
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
        isEmptyStateDeferredUntilActive = false
        withAnimation(DesignSystem.Animation.easeInOutFaster) {
            overlayState?.emptyState = nil
        }
        reconnectManager?.stop()
        // The next failed load re-derives it; the next successful one has nothing to derive.
        clientCertificateIssue = nil
    }

    var shouldShowErrorDetailsButton: Bool {
        connectionState == .disconnected && latestLoadError != nil
    }

    /// The scene this frontend is shown in, once its view is in a window.
    var frontendWindowScene: UIWindowScene? {
        viewIfLoaded?.window?.windowScene
    }

    @objc func sceneDidEnterBackground(_ notification: Notification) {
        guard concernsFrontendScene(notification) else { return }
        handleSceneDidEnterBackground()
    }

    @objc func sceneDidActivate(_ notification: Notification) {
        guard concernsFrontendScene(notification) else { return }
        handleSceneDidActivate()
    }

    /// Scene notifications are posted for every scene in the process, and with several windows open the
    /// others' transitions say nothing about this frontend. A frontend that is not in a window cannot
    /// tell the scenes apart, so for it every scene counts, as the application's state would.
    private func concernsFrontendScene(_ notification: Notification) -> Bool {
        guard let scene = notification.object as? UIScene else { return false }
        guard let frontendWindowScene else { return true }
        return scene === frontendWindowScene
    }

    func handleSceneDidEnterBackground() {
        didEnterBackgroundSinceLastActivation = true
    }

    /// Settles what the background left behind now that the outcome is visible. A deferred empty state
    /// does not simply appear: a frontend whose page failed to load is reloaded, which puts the loader up
    /// and lets a failure that persists show the empty state right away, and a frontend whose page is
    /// still there gets the grace period to reconnect on its own. A grace period that was already running
    /// when the scene went to the background starts over, since the frontend could not use the part the
    /// scene slept through.
    func handleSceneDidActivate() {
        // What the frontend reported while the scene was away settles the connection state read below, and a
        // page that loaded in the background is still waiting for its `config/get` reply.
        webViewScriptMessageHandler.deliverDeferredMessages()

        let returnedFromBackground = didEnterBackgroundSinceLastActivation
        didEnterBackgroundSinceLastActivation = false

        guard isEmptyStateDeferredUntilActive else {
            if returnedFromBackground, emptyStateTimer != nil {
                Current.Log.info("Restarting the empty state grace period after returning from the background")
                scheduleEmptyStateAfterGracePeriod()
            }
            return
        }
        isEmptyStateDeferredUntilActive = false

        guard !connectionState.isReadyForDisplay, overlayState?.emptyState == nil else { return }

        if latestLoadError != nil || contentProcessTerminations > 0 {
            Current.Log.info("Reloading the frontend that failed while the scene was not active")
            refresh()
        } else {
            Current.Log.info("Giving the frontend its grace period to reconnect now that the scene is active")
            scheduleEmptyStateAfterGracePeriod()
        }
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
        let presentableError = Self.presentableExternalAuthError(for: error)
        latestLoadError = presentableError
        // The token request goes through the app's own session, whose challenges this controller never
        // sees, so only the error code can tell a certificate problem apart from a connectivity one.
        if let issue = Self.clientCertificateIssue(
            for: presentableError,
            receivedClientCertificateChallenge: false,
            hasClientCertificate: server.info.connection.clientCertificate != nil
        ) {
            clientCertificateIssue = issue
            if overlayState?.emptyState != nil {
                // Already up as a connectivity failure; swap in the certificate copy and action.
                showEmptyState()
            }
        }

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
            clientCertificateAction: { [weak self] in self?.presentClientCertificateImport() },
            dismissAction: { [weak self] in self?.hideEmptyState() }
        )
    }
}
