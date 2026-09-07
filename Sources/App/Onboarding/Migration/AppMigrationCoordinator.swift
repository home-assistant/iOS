import FirebaseMessaging
import Foundation
import Shared
import UIKit

/// Drives the handoff on whichever side this build is. The new app mints a session, asks the previous
/// app for its setup and applies what comes back; the previous app hands control to the transfer
/// screen on request, packages its setup, and stays on that screen until it is erased.
@MainActor
final class AppMigrationCoordinator: ObservableObject {
    static let shared = AppMigrationCoordinator()
    static let handoffDidChange = Notification.Name("AppMigrationCoordinator.handoffDidChange")

    let role = AppMigrationRole.current

    @Published private(set) var importState: AppMigrationImportState?
    @Published private(set) var completedSummary: AppMigrationSummary?
    @Published private(set) var exportRequest: AppMigrationSession?
    @Published private(set) var exportState: AppMigrationExportState = .idle
    @Published private(set) var handoffPhase: AppMigrationHandoffPhase?

    private var session: AppMigrationSession?

    private init() {
        self.handoffPhase = AppMigrationHandoffStore.load()
        switch handoffPhase {
        case let .requested(request):
            self.exportRequest = request
        case .handedOff:
            self.exportState = .handedOff
        case .erased:
            self.exportState = .erased
        case nil:
            break
        }
    }

    var isPreviousAppInstalled: Bool {
        role == .newApp && UIApplication.shared.canOpenURL(AppMigrationRole.previousApp.baseURL)
    }

    var exportSummary: AppMigrationSummary {
        AppMigrationSummary(serverNames: Current.servers.all.map(\.info.name))
    }

    /// Runs before anything connects at launch, so a relaunch during or after a handoff stays silent.
    func restoreHandoffIfNeeded() {
        guard role == .previousApp, handoffPhase != nil else { return }
        HomeAssistantAPI.connectionsSuspended = true
        switch handoffPhase {
        case .handedOff, .erased:
            releasePushRegistration()
        case .requested, nil:
            break
        }
    }

    @discardableResult
    func handle(url: URL) -> Bool {
        guard let link = AppMigrationLink(url: url) else { return false }
        switch (role, link) {
        case let (.newApp, .payloadReady(sessionID)):
            receivePayload(sessionID: sessionID)
        case let (.newApp, .declined(sessionID)):
            guard currentSession()?.id == sessionID else { return false }
            importState = .failed(message: AppMigrationError.declined.localizedDescription)
        case (.newApp, .restart):
            restartImport()
        case let (.previousApp, .request(requested)):
            if case .erased = handoffPhase {
                Task { _ = await open(AppMigrationLink.declined(sessionID: requested.id).url(to: .newApp)) }
            } else {
                enterTakeover(with: requested)
            }
        default:
            return false
        }
        return true
    }

    // MARK: New app

    func startImport() {
        let session = AppMigrationSession.make()
        self.session = session
        AppMigrationSessionStore.save(session)
        completedSummary = nil
        importState = .waitingForPreviousApp
        openPreviousApp()
    }

    func openPreviousApp() {
        guard let session = currentSession() else { return }
        Task {
            if await !open(AppMigrationLink.request(session).url(to: .previousApp)) {
                importState = .failed(message: AppMigrationError.previousAppUnavailable.localizedDescription)
            }
        }
    }

    func cancelImport() {
        session = nil
        AppMigrationSessionStore.clear()
        importState = nil
    }

    func finishImport() {
        completedSummary = nil
        cancelImport()
    }

    private func currentSession() -> AppMigrationSession? {
        if session == nil {
            session = AppMigrationSessionStore.load()
        }
        return session
    }

    private func receivePayload(sessionID: UUID) {
        guard let session = currentSession(), session.id == sessionID else {
            importState = .failed(message: AppMigrationError.wrongSession.localizedDescription)
            return
        }
        importState = .receiving
        guard let sealed = AppMigrationPasteboard.read() else {
            importState = .failed(message: AppMigrationError.noPayload.localizedDescription)
            return
        }
        AppMigrationPasteboard.clear()
        Task {
            do {
                let payload = try await Task.detached {
                    let data = try AppMigrationCrypto.open(sealed, key: session.key)
                    return try JSONDecoder().decode(AppMigrationPayload.self, from: data)
                }.value
                guard payload.sessionID == sessionID else { throw AppMigrationError.wrongSession }
                importState = .applying
                let summary = try await Task.detached {
                    try AppMigrationImporter().apply(payload)
                }.value
                AppMigrationSessionStore.clear()
                self.session = nil
                importState = nil
                completedSummary = summary
                adoptPushRegistration()
            } catch {
                Current.Log.error("App migration import failed: \(error)")
                importState = .failed(message: error.localizedDescription)
            }
        }
    }

    /// The transferred registration still carries the previous app's push token: Home Assistant merges
    /// `update_registration` into what it has, so the token only changes once this app sends its own.
    /// Connecting right away does that, and also brings the websocket up for the imported servers.
    private func adoptPushRegistration() {
        Messaging.messaging().token { token, error in
            Task { @MainActor in
                if let token {
                    Current.settingsStore.pushID = token
                } else if let error {
                    Current.Log.error("No push token to hand to the transferred registration yet: \(error)")
                }
                for api in Current.apis {
                    _ = api.Connect(reason: .warm)
                }
            }
        }
    }

    /// The previous app asked to redo the transfer: drop everything received so far, then request again.
    private func restartImport() {
        wipeLocalData()
        completedSummary = nil
        startImport()
        Current.onboardingObservation.needed(.logout)
    }

    // MARK: Previous app

    func transfer() {
        guard let request = exportRequest else { return }
        exportState = .preparing
        Task {
            do {
                let sealed = try await Task.detached {
                    let payload = try AppMigrationExporter().makePayload(sessionID: request.id)
                    let data = try JSONEncoder().encode(payload)
                    return try AppMigrationCrypto.seal(data, key: request.key)
                }.value
                AppMigrationPasteboard.write(sealed)
                if await open(AppMigrationLink.payloadReady(sessionID: request.id).url(to: .newApp)) {
                    exportState = .handedOff
                    setHandoffPhase(.handedOff)
                    releasePushRegistration()
                } else {
                    AppMigrationPasteboard.clear()
                    exportState = .failed(message: AppMigrationError.newAppUnavailable.localizedDescription)
                }
            } catch {
                Current.Log.error("App migration export failed: \(error)")
                exportState = .failed(message: error.localizedDescription)
            }
        }
    }

    func openNewApp() {
        Task { _ = await open(AppMigrationRole.newApp.baseURL) }
    }

    func transferAgain() {
        Task { _ = await open(AppMigrationLink.restart.url(to: .newApp)) }
    }

    /// Leaves the takeover: tells the new app, forgets the handoff and lets this app reconnect.
    func declineExport() {
        if let request = exportRequest {
            Task { _ = await open(AppMigrationLink.declined(sessionID: request.id).url(to: .newApp)) }
        }
        exportRequest = nil
        exportState = .idle
        setHandoffPhase(nil)
        resumeConnections()
    }

    func eraseApp() {
        wipeLocalData()
        exportRequest = nil
        exportState = .erased
        setHandoffPhase(.erased)
    }

    /// Once the setup has left this app, pushes must not land here even if Home Assistant still holds
    /// the old token for a moment: drop the APNs registration and invalidate the FCM token.
    private func releasePushRegistration() {
        UIApplication.shared.unregisterForRemoteNotifications()
        Messaging.messaging().deleteToken { error in
            if let error {
                Current.Log.error("Failed to delete the previous app's push token: \(error)")
            }
        }
    }

    private func enterTakeover(with request: AppMigrationSession) {
        exportRequest = request
        exportState = .idle
        suspendConnections()
        closeOtherWindows()
        setHandoffPhase(.requested(request))
    }

    private func setHandoffPhase(_ phase: AppMigrationHandoffPhase?) {
        handoffPhase = phase
        AppMigrationHandoffStore.save(phase)
        NotificationCenter.default.post(name: Self.handoffDidChange, object: nil)
    }

    private func suspendConnections() {
        HomeAssistantAPI.connectionsSuspended = true
        Current.modelManager.unsubscribe()
        for api in Current.apis {
            api.connection.disconnect()
        }
        Current.sceneManager.webViewControllerPromise.done { [weak self] controller in
            guard self?.handoffPhase != nil, let webView = controller.webView else { return }
            webView.stopLoading()
            webView.load(URLRequest(url: URL(string: "about:blank")!))
        }
    }

    private func resumeConnections() {
        HomeAssistantAPI.connectionsSuspended = false
        Current.modelManager.subscribe(isAppInForeground: { UIApplication.shared.applicationState == .active })
        for api in Current.apis {
            _ = api.Connect(reason: .warm)
        }
    }

    private func wipeLocalData() {
        for api in Current.apis {
            api.connection.disconnect()
        }
        let identifiers = Current.servers.all.map(\.identifier)
        Current.servers.removeAll()
        Current.resetAPICache(for: identifiers)
        resetStores()
    }

    /// Mac Catalyst keeps the window showing the transfer and closes every other one.
    private func closeOtherWindows() {
        guard Current.isCatalyst else { return }
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let webViewScenes = windowScenes.filter {
            SceneActivity(configurationName: $0.session.configuration.name ?? "") == .webView
        }
        let keep = webViewScenes.first { $0.activationState == .foregroundActive } ?? webViewScenes.first
        for scene in windowScenes where scene !== keep {
            UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil, errorHandler: nil)
        }
    }

    private func open(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { continuation.resume(returning: $0) }
        }
    }
}
