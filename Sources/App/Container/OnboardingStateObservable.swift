import Combine
import PromiseKit
import Shared
import SwiftUI
import UIKit

enum RecoveredServerReauthenticationError: LocalizedError {
    case missingPresenter
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingPresenter: return L10n.Onboarding.ServerImport.Reauthenticate.errorsMissingPresenter
        case .cancelled: return L10n.Onboarding.ServerImport.Reauthenticate.errorsCancelled
        }
    }
}

/// Exposes, for SwiftUI, which top-level screen the app should show — the state engine behind
/// `ContainerView`. Replaces the `OnboardingStateObserver` role `WebViewWindowController` performed via
/// root-view-controller swapping (including the launch recovered-server import / re-auth flow).
@MainActor
final class OnboardingStateObservable: ObservableObject {
    enum Screen: Equatable {
        case onboarding(OnboardingStyle)
        case webView(Server)
        case recoveredServerImport
        case recoveredServerReauth(Server)
    }

    @Published private(set) var screen: Screen

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.screen = Self.initialScreen()
        Current.onboardingObservation.register(observer: self)
        observeKioskTarget()
        observeLocationBasedServerSwitch()
    }

    /// Switches the displayed screen to `server`'s web view. Called by the app coordinator's `open(server:)`.
    func showWebView(for server: Server) {
        screen = .webView(server)
    }

    /// A change to the kiosk server requires a different web view (rebuilt by `ContainerView` via the
    /// `.id(server)`); a change to just the dashboard navigates the current web view in place.
    private struct KioskWebTarget: Equatable {
        let enabled: Bool
        let serverId: String?
        let dashboard: String?
    }

    /// Live-updates the web view as the kiosk server/dashboard pickers change, so the configured
    /// dashboard appears in the web view behind the kiosk settings sheet.
    private func observeKioskTarget() {
        Current.kiosk.settingsPublisher
            .map { KioskWebTarget(enabled: $0.enabled, serverId: $0.serverId, dashboard: $0.dashboard) }
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] target in
                self?.applyKioskTarget(target)
            }
            .store(in: &cancellables)
    }

    private func applyKioskTarget(_ target: KioskWebTarget) {
        guard target.enabled, let server = Current.servers.server(forServerIdentifier: target.serverId) else { return }
        if currentServer != server {
            // Different server: rebuild the web view, which loads its kiosk dashboard on creation.
            showWebView(for: server)
        } else {
            // Same server: just navigate the existing web view to the configured dashboard.
            Current.sceneManager.webViewControllerPromise.done { $0.applyKioskDashboard() }
        }
    }

    private var currentServer: Server? {
        if case let .webView(server) = screen { return server }
        return nil
    }

    /// Re-evaluates the location-based server whenever the app returns to the foreground, when the
    /// setting is toggled, and once after launch (the synchronous launch decision can only use cached
    /// state — e.g. the current SSID is fetched asynchronously and may not be known yet when
    /// `initialScreen()` runs).
    private func observeLocationBasedServerSwitch() {
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .merge(with: NotificationCenter.default.publisher(for: SettingsStore.locationRelatedSettingDidChange))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.switchToLocationBasedServerIfNeeded()
            }
            .store(in: &cancellables)
        switchToLocationBasedServerIfNeeded()
    }

    /// Switches the web view to the server matching the user's current network/location, unless the
    /// user intentionally switched to another server recently (manual-selection grace period).
    private func switchToLocationBasedServerIfNeeded() {
        guard Current.locationBasedServerSwitcher.isEnabled else { return }
        Task { @MainActor [weak self] in
            guard let preferred = await Current.locationBasedServerSwitcher.preferredServer() else { return }
            guard let self, case let .webView(current) = screen else { return }
            guard current.identifier != preferred.identifier else { return }
            guard !Current.locationBasedServerSwitcher.isManualSelectionActive(for: current) else {
                Current.Log.verbose(
                    "not switching to location-based server \(preferred.identifier): manual selection active"
                )
                return
            }
            Current.Log.info("switching to location-based server \(preferred.identifier)")
            screen = .webView(preferred)
        }
    }

    /// Recomputes which screen to show (e.g. after onboarding finishes). Mirrors the launch decision.
    func reevaluate() {
        screen = Self.initialScreen()
    }

    /// Restores the keychain from the mirror, then re-evaluates once the import screen has shown briefly.
    func completeRecoveredServerImport() {
        _ = Current.servers.restoreKeychainFromMirrorIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.reevaluate()
        }
    }

    func handleRecoveredServerSelection(_ server: Server) {
        if server.info.requiresReauthenticationAfterMirrorRestore {
            screen = .recoveredServerReauth(server)
        } else {
            showWebView(for: server)
        }
    }

    func availableReauthURLTypes(for server: Server) -> [ConnectionInfo.URLType] {
        let preferenceOrder: [ConnectionInfo.URLType] = [.remoteUI, .external, .internal]
        return preferenceOrder.filter { server.info.connection.address(for: $0) != nil }
    }

    /// Re-authenticates a server recovered from a keychain-mirror restore, then shows its web view.
    /// Moved from `WebViewWindowController`; `presenter` comes from the re-auth screen's hosting controller.
    func performRecoveredServerReauthentication(
        for server: Server,
        using urlType: ConnectionInfo.URLType,
        presenter: UIViewController?,
        completion: @escaping (Swift.Result<Void, Error>) -> Void
    ) {
        let connectionInfo = server.info.connection
        guard let baseURL = connectionInfo.address(for: urlType) else {
            completion(.failure(ServerConnectionError.noActiveURL(server.info.name)))
            return
        }
        guard let presenter else {
            completion(.failure(RecoveredServerReauthenticationError.missingPresenter))
            return
        }
        do {
            let authDetails = try OnboardingAuthDetails(baseURL: baseURL)
            authDetails.exceptions = connectionInfo.securityExceptions
            authDetails.clientCertificate = connectionInfo.clientCertificate
            let login = OnboardingAuthLoginImpl()
            firstly {
                login.open(authDetails: authDetails, sender: presenter)
            }.then { result -> Promise<(URL?, TokenInfo)> in
                let correctedURL = result.resolvedURL?.sameHostRedirectBaseURL(from: baseURL)
                return AuthenticationAPI.fetchToken(
                    authorizationCode: result.code,
                    baseURL: correctedURL ?? baseURL,
                    exceptions: authDetails.exceptions,
                    clientCertificate: authDetails.clientCertificate
                ).map { (correctedURL, $0) }
            }.done { [weak self] correctedURL, tokenInfo in
                server.update { serverInfo in
                    serverInfo.token = tokenInfo
                    if let correctedURL {
                        Current.Log.info("Updating \(urlType) URL to redirect \(correctedURL) during re-auth")
                        serverInfo.connection.set(address: correctedURL, for: urlType)
                    }
                }
                completion(.success(()))
                self?.showWebView(for: server)
            }.catch { error in
                if let pmkError = error as? PMKError, pmkError.isCancelled {
                    completion(.failure(RecoveredServerReauthenticationError.cancelled))
                    return
                }
                Current.Log.error("Recovered server re-authentication failed: \(error)")
                completion(.failure(error))
            }
        } catch {
            Current.Log.error("Failed to create auth details for recovered server re-authentication: \(error)")
            completion(.failure(error))
        }
    }

    /// Mirrors `WebViewWindowController.setup()`: onboarding when required, otherwise the first server's
    /// web view.
    private static func initialScreen() -> Screen {
        if Current.servers.isMirrorRestorePending {
            return .recoveredServerImport
        }
        if let server = recoveredServerNeedingReauthentication() {
            return .recoveredServerReauth(server)
        }
        if let style = OnboardingNavigation.requiredOnboardingStyle {
            return .onboarding(style)
        }
        if let server = preferredInitialServer() {
            return .webView(server)
        }
        return .onboarding(.initial)
    }

    /// The server to show at launch: the kiosk-configured server when kiosk mode is enabled, then the
    /// location-based server (or a recent manual selection) when auto-switching is on, otherwise the
    /// first registered server.
    private static func preferredInitialServer() -> Server? {
        let kiosk = Current.kioskSettings
        if kiosk.enabled, let server = Current.servers.server(forServerIdentifier: kiosk.serverId) {
            return server
        }
        let switcher = Current.locationBasedServerSwitcher
        if switcher.isEnabled {
            if let manuallySelected = switcher.activeManualSelection {
                return manuallySelected
            }
            if let preferred = switcher.preferredServerUsingCachedState() {
                return preferred
            }
        }
        return Current.servers.all.first
    }

    /// The server shown at launch (preferring one that doesn't need re-auth), if it requires re-auth after a
    /// keychain-mirror restore. Mirrors `WebViewWindowController.nextRecoveredServerNeedingReauthentication`.
    private static func recoveredServerNeedingReauthentication() -> Server? {
        let preferred = Current.servers.all.first { !$0.info.requiresReauthenticationAfterMirrorRestore }
            ?? Current.servers.all.first
        guard let preferred, preferred.info.requiresReauthenticationAfterMirrorRestore else { return nil }
        return preferred
    }

    private func apply(_ state: OnboardingState) {
        switch state {
        case let .needed(type):
            switch type {
            case .error, .logout:
                // A server was removed / logged out. Fall back to another server if one remains,
                // otherwise restart onboarding. Mirrors `WebViewWindowController.onboardingStateDidChange`.
                if let server = Current.servers.all.first {
                    screen = .webView(server)
                } else {
                    screen = .onboarding(.initial)
                }
            case .unauthenticated:
                // Re-authentication is surfaced by the active WebViewController itself, so keep showing
                // the web view rather than swapping the top-level screen.
                break
            }
        case .complete:
            if let server = Current.servers.all.first {
                screen = .webView(server)
            }
        case .didConnect:
            // Connection established mid-onboarding; the `.complete` transition drives the screen swap.
            break
        }
    }
}

extension OnboardingStateObservable: OnboardingStateObserver {
    // `OnboardingStateObservation` may notify from a non-main thread, so hop to the main actor before
    // mutating the published `screen`.
    nonisolated func onboardingStateDidChange(to state: OnboardingState) {
        Task { @MainActor [weak self] in
            self?.apply(state)
        }
    }
}
