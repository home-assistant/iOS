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

    init() {
        self.screen = Self.initialScreen()
        Current.onboardingObservation.register(observer: self)
    }

    /// Switches the displayed screen to `server`'s web view. Called by the app coordinator's `open(server:)`.
    func showWebView(for server: Server) {
        screen = .webView(server)
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
        if let server = Current.servers.all.first {
            return .webView(server)
        }
        return .onboarding(.initial)
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
