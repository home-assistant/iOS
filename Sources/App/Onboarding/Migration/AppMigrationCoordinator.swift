import Foundation
import Shared
import UIKit

/// Drives the handoff on whichever side this build is. The new app mints a session, asks the previous
/// app for its setup and applies what comes back; the previous app packages its setup on request.
@MainActor
final class AppMigrationCoordinator: ObservableObject {
    static let shared = AppMigrationCoordinator()

    let role = AppMigrationRole.current

    @Published private(set) var importState: AppMigrationImportState?
    @Published private(set) var completedSummary: AppMigrationSummary?
    @Published private(set) var exportRequest: AppMigrationSession?
    @Published private(set) var exportState: AppMigrationExportState = .idle

    private var session: AppMigrationSession?

    var isPreviousAppInstalled: Bool {
        role == .newApp && UIApplication.shared.canOpenURL(AppMigrationRole.previousApp.baseURL)
    }

    var exportSummary: AppMigrationSummary {
        AppMigrationSummary(serverNames: Current.servers.all.map(\.info.name))
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
        case let (.previousApp, .request(requested)):
            exportRequest = requested
            exportState = .idle
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
            } catch {
                Current.Log.error("App migration import failed: \(error)")
                importState = .failed(message: error.localizedDescription)
            }
        }
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

    func declineExport() {
        if let request = exportRequest {
            Task { _ = await open(AppMigrationLink.declined(sessionID: request.id).url(to: .newApp)) }
        }
        exportRequest = nil
        exportState = .idle
    }

    private func open(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { continuation.resume(returning: $0) }
        }
    }
}
