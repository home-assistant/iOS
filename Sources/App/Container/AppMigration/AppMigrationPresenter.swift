import Foundation
import Shared
import SwiftUI

/// Decides when either half of the migration is on screen, and routes the URLs the two apps exchange.
///
/// It is a singleton for the same reason `AppSettingsPresenter` is: the handoff can arrive at any
/// moment, from a URL that reaches the app before any particular view exists.
///
/// Everything here is called from the main thread — URL delivery, scene-phase changes and SwiftUI
/// bodies all arrive on it — matching `AppSettingsPresenter` next door.
final class AppMigrationPresenter: ObservableObject {
    static let shared = AppMigrationPresenter()

    @Published var presentation: AppMigrationPresentation?

    private var didPromptThisLaunch = false

    private init() {}

    /// Handles the URLs the two apps send each other. Returns whether the URL was a migration one, so
    /// the caller knows not to route it anywhere else.
    @discardableResult
    func handle(url: URL) -> Bool {
        switch AppMigrationRole.current {
        case .destination:
            guard let chunk = AppMigrationLink.importChunk(from: url) else { return false }
            Current.Log.info("Received app migration chunk \(chunk.index + 1)/\(chunk.total)")
            presentation = .importing(chunk: chunk)
            // Same session, so the screen is already up and holding the slices received so far;
            // nudge it rather than rebuilding it.
            NotificationCenter.default.post(
                name: .appMigrationDidReceiveChunk,
                object: nil,
                userInfo: [AppMigrationContinuationKey.chunk: chunk]
            )
            return true
        case .source:
            if let continuation = AppMigrationLink.continuation(from: url) {
                Current.Log.info("The new app asked for chunk \(continuation.nextIndex + 1)")
                if presentation != .export {
                    presentation = .export
                }
                NotificationCenter.default.post(
                    name: .appMigrationDidRequestNextChunk,
                    object: nil,
                    userInfo: [
                        AppMigrationContinuationKey.sessionID: continuation.sessionID,
                        AppMigrationContinuationKey.nextIndex: continuation.nextIndex,
                    ]
                )
                return true
            }
            guard let serverCount = AppMigrationLink.completedServerCount(from: url) else { return false }
            Current.Log.info("The new app confirmed importing \(serverCount) server(s)")
            // The flow may not be on screen — the user can have dismissed it while the new app was
            // in front — so bring it back to show the confirmation and let it retire this app.
            if presentation != .export {
                presentation = .export
            }
            NotificationCenter.default.post(
                name: .appMigrationDidComplete,
                object: nil,
                userInfo: [AppMigrationCompletionKey.serverCount: serverCount]
            )
            return true
        }
    }

    /// Opened from Settings.
    func presentExportFlow() {
        presentation = .export
    }

    /// Offers the migration on launch, at most once per launch and only while there is something to
    /// migrate. A user with no servers has nothing to move and is better served by just signing in.
    func promptIfNeeded() {
        guard !didPromptThisLaunch,
              presentation == nil,
              AppMigrationStatus.shouldPrompt,
              !Current.servers.all.isEmpty else {
            return
        }
        didPromptThisLaunch = true
        presentation = .export
    }

    func dismiss() {
        presentation = nil
    }
}
