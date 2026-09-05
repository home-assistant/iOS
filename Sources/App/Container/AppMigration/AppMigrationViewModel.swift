import Foundation
import Shared
import SwiftUI
import UIKit

/// Drives the migration on the app being replaced: packaging the data, handing it to the new app,
/// and reacting to the new app's confirmation.
@MainActor
final class AppMigrationViewModel: ObservableObject {
    @Published private(set) var phase: AppMigrationPhase = .intro
    @Published private(set) var stepStates: [AppMigrationExportStep: AppMigrationStepState] = [:]
    @Published private(set) var serverCount = Current.servers.all.count
    /// Only set while a payload is crossing in more than one link.
    @Published private(set) var transfer: AppMigrationTransferProgress?

    /// Each step is held on screen for at least this long. Packaging is fast enough to finish before
    /// the user can read the list, and a list that fills in instantly reads as "nothing happened".
    private static let minimumStepDuration: TimeInterval = 0.55

    private var chunks: [AppMigrationChunk] = []
    private var confirmationObserver: NSObjectProtocol?
    private var continuationObserver: NSObjectProtocol?

    init() {
        self.confirmationObserver = NotificationCenter.default.addObserver(
            forName: .appMigrationDidComplete,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let count = notification.userInfo?[AppMigrationCompletionKey.serverCount] as? Int ?? 0
            Task { @MainActor in self?.handleConfirmation(serverCount: count) }
        }
        self.continuationObserver = NotificationCenter.default.addObserver(
            forName: .appMigrationDidRequestNextChunk,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let sessionID = notification.userInfo?[AppMigrationContinuationKey.sessionID] as? String,
                  let index = notification.userInfo?[AppMigrationContinuationKey.nextIndex] as? Int else {
                return
            }
            Task { @MainActor in self?.sendChunk(at: index, sessionID: sessionID) }
        }
    }

    deinit {
        for observer in [confirmationObserver, continuationObserver].compactMap({ $0 }) {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func state(for step: AppMigrationExportStep) -> AppMigrationStepState {
        stepStates[step] ?? .pending
    }

    /// Packages everything and hands it over. Safe to call again after a failure.
    func start() async {
        AppMigrationHaptics.stepCompleted()
        chunks = []
        transfer = nil
        stepStates = [:]
        phase = .packaging

        do {
            let servers = try await run(.servers) { AppMigrationExporter.serversState() }
            let configuration = await runIgnoringFailure(.configuration) {
                let appSettings = AppSettingsSnapshot.capture()
                return try await Task.detached(priority: .userInitiated) {
                    try AppMigrationExporter.configurationData(appSettings: appSettings)
                }.value
            }

            let chunks = try await run(.packaging) { () -> [AppMigrationChunk] in
                let payload = AppMigrationExporter.makePayload(
                    servers: servers,
                    configuration: configuration,
                    serverCount: Current.servers.all.count
                )
                self.serverCount = payload.serverCount
                return try AppMigrationPayloadCoder.chunks(for: payload, sessionID: UUID().uuidString)
            }
            self.chunks = chunks

            try await run(.handoff) { try self.send(chunks[0]) }
        } catch {
            fail(with: error)
        }
    }

    /// Re-opens the new app with the payload already packaged — used by the "not installed yet" and
    /// "still waiting" screens, so the user never has to package twice. Resumes at the slice the new
    /// app has not acknowledged rather than starting the handover again.
    func openDestinationAgain() {
        guard let next = chunks.first(where: { $0.index == nextIndex }) else {
            Task { await start() }
            return
        }
        do {
            try send(next)
        } catch {
            fail(with: error)
        }
    }

    func openAppStore() {
        UIApplication.shared.open(AppMigrationConstants.destinationAppStoreURL)
    }

    /// "Later", from the failure screen: throws away the half-finished attempt and gets out of the
    /// way so the user can carry on using Home Assistant. Nothing has been handed over, this app
    /// still holds every server, and it has not been retired — so putting the move off costs the
    /// user nothing but the time it takes to start it again.
    ///
    /// Only local state is cleared. A partial payload sitting in the new app cannot be reached from
    /// here, but it is keyed by session, so the next attempt discards it on its first slice.
    func cancelAfterFailure() {
        Current.Log.info("Abandoning the migration after a failure; the app carries on as normal")
        chunks = []
        transfer = nil
        stepStates = [:]
        nextIndex = 0
        AppMigrationChunkStore.clear()
        snoozePrompt()
        phase = .intro
    }

    /// "Not now": stays out of the way for a few days rather than asking again on the next launch.
    func snoozePrompt() {
        AppMigrationStatus.promptDismissedAt = Current.date()
    }

    // MARK: - Private

    /// Index of the next slice to hand over. Zero until the new app asks for more.
    private var nextIndex = 0

    /// Sends the slice the new app asked for. A session mismatch means the request belongs to an
    /// abandoned attempt, so it is ignored rather than mixed into this one.
    private func sendChunk(at index: Int, sessionID: String) {
        guard let chunk = chunks.first(where: { $0.index == index && $0.sessionID == sessionID }) else {
            Current.Log.info("Ignoring a request for chunk \(index) of an unknown migration session")
            return
        }
        do {
            try send(chunk)
        } catch {
            fail(with: error)
        }
    }

    private func send(_ chunk: AppMigrationChunk) throws {
        nextIndex = chunk.index
        guard let url = AppMigrationLink.importURL(chunk: chunk) else {
            throw AppMigrationCodingError.malformedPayload
        }

        // Only worth showing when there is genuinely more than one link to hand over; a bar that
        // fills the instant it appears is noise.
        if chunk.total > 1 {
            transfer = .init(completed: chunk.index, total: chunk.total)
            AppMigrationHaptics.transferAdvanced()
        } else {
            transfer = nil
        }

        // A universal link opens Safari when the new app is not installed, which is a fine place to
        // land — the App Store link lives there. A custom scheme opens nothing at all, so check
        // first and show the install screen ourselves.
        let isCustomScheme = AppMigrationConstants.destinationUniversalLinkBase == nil
        if isCustomScheme, !UIApplication.shared.canOpenURL(url) {
            Current.Log.info("New app is not installed; showing the install step")
            phase = .needsDestinationApp
            return
        }

        Current.Log.info("Handing over chunk \(chunk.index + 1)/\(chunk.total)")
        phase = .awaitingConfirmation
        UIApplication.shared.open(url, options: [:]) { [weak self] opened in
            guard !opened else { return }
            Current.Log.error("Failed to open the new app for migration")
            Task { @MainActor in self?.phase = .needsDestinationApp }
        }
    }

    private func handleConfirmation(serverCount: Int) {
        transfer = nil
        AppMigrationRetirement.retire(importedServerCount: serverCount)
        AppMigrationHaptics.migrationSucceeded()
        phase = .completed(serverCount: serverCount)
    }

    private func fail(with error: Error) {
        Current.Log.error("App migration failed: \(error.localizedDescription)")
        AppMigrationHaptics.migrationFailed()
        phase = .failed(message: error.localizedDescription)
    }

    /// Runs one step, holding it on screen long enough to be seen and marking it failed if it throws.
    @discardableResult
    private func run<T>(_ step: AppMigrationExportStep, _ work: () async throws -> T) async throws -> T {
        set(step, to: .running)
        do {
            async let paced: Void = pace()
            let result = try await work()
            await paced
            set(step, to: .done)
            AppMigrationHaptics.stepCompleted()
            return result
        } catch {
            set(step, to: .failed)
            AppMigrationHaptics.stepFailed()
            throw error
        }
    }

    /// Same as `run`, but a failure only marks the step and yields `nil`: the configuration half is
    /// worth having and not worth abandoning the migration over.
    private func runIgnoringFailure<T>(
        _ step: AppMigrationExportStep,
        _ work: () async throws -> T
    ) async -> T? {
        do {
            return try await run(step, work)
        } catch {
            Current.Log.error("Optional app migration step \(step.rawValue) failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func set(_ step: AppMigrationExportStep, to state: AppMigrationStepState) {
        withAnimation { stepStates[step] = state }
    }

    private func pace() async {
        try? await Task.sleep(nanoseconds: UInt64(Self.minimumStepDuration * 1_000_000_000))
    }
}
