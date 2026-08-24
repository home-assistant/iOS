import Foundation
import Shared
import SwiftUI
import UIKit

/// Drives an incoming migration on the app taking over: collecting the handoff, applying it, and
/// telling the app it replaces that it can stand down.
///
/// A payload that fit in one link is applied immediately. One that did not arrives a slice at a
/// time: each slice is stored, and this asks the other app for the next one, which is the only
/// reason the user ever sees the two apps swap. The payload is decoded here rather than at the URL
/// handler so a corrupt or too-new handoff fails visibly inside the flow, with a message, instead of
/// being dropped before anything is shown.
@MainActor
final class AppMigrationImportViewModel: ObservableObject {
    @Published private(set) var phase: AppMigrationImportPhase = .running
    @Published private(set) var stepStates: [AppMigrationImportStep: AppMigrationStepState] = [:]
    /// Only set while a payload is arriving in more than one link.
    @Published private(set) var transfer: AppMigrationTransferProgress?

    private static let minimumStepDuration: TimeInterval = 0.55

    private var chunk: AppMigrationChunk
    private var arrivalObserver: NSObjectProtocol?

    init(chunk: AppMigrationChunk) {
        self.chunk = chunk
        self.arrivalObserver = NotificationCenter.default.addObserver(
            forName: .appMigrationDidReceiveChunk,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let next = notification.userInfo?[AppMigrationContinuationKey.chunk] as? AppMigrationChunk
            else { return }
            Task { @MainActor in await self?.accept(next) }
        }
    }

    deinit {
        if let arrivalObserver {
            NotificationCenter.default.removeObserver(arrivalObserver)
        }
    }

    /// A further slice arrived for the handoff already on screen. The screen stays put and the steps
    /// keep their state, so a multi-link transfer reads as one continuous operation.
    private func accept(_ chunk: AppMigrationChunk) async {
        guard chunk.sessionID == self.chunk.sessionID else { return }
        self.chunk = chunk
        await run()
    }

    func state(for step: AppMigrationImportStep) -> AppMigrationStepState {
        stepStates[step] ?? .pending
    }

    func run() async {
        stepStates = [:]
        phase = .running

        transfer = chunk.total > 1 ? .init(completed: chunk.index, total: chunk.total) : nil

        do {
            let assembled = try await run(.reading) { () -> String in
                guard let assembled = AppMigrationChunkStore.accept(self.chunk) else {
                    throw AppMigrationImportPause.awaitingMoreChunks
                }
                return assembled
            }
            transfer = chunk.total > 1 ? .init(completed: chunk.total, total: chunk.total) : nil
            let payload = try AppMigrationPayloadCoder.payload(fromAssembled: assembled)
            let serverCount = try await run(.servers) {
                AppMigrationImporter.importServers(from: payload)
            }
            let configuration = try await run(.configuration) {
                await AppMigrationImporter.importConfiguration(from: payload)
            }
            let summary = AppMigrationImportSummary(
                serverCount: serverCount,
                configurationEntryCount: configuration.count,
                configurationFailed: configuration.failed
            )
            try await run(.finishing) {
                AppMigrationImporter.finish(summary: summary)
            }

            AppMigrationHaptics.migrationSucceeded()
            phase = .completed(summary)
        } catch is AppMigrationImportPause {
            // Not a failure: the rest of the payload is still in the other app. Hand control back so
            // it can send the next slice, and stay on this screen so the user sees one continuous
            // transfer rather than the flow restarting on every round trip.
            requestNextChunk()
        } catch {
            Current.Log.error("Incoming app migration failed: \(error.localizedDescription)")
            AppMigrationHaptics.migrationFailed()
            phase = .failed(message: error.localizedDescription)
        }
    }

    @discardableResult
    private func run<T>(_ step: AppMigrationImportStep, _ work: () async throws -> T) async throws -> T {
        set(step, to: .running)
        do {
            async let paced: Void = pace()
            let result = try await work()
            await paced
            set(step, to: .done)
            AppMigrationHaptics.stepCompleted()
            return result
        } catch {
            if !(error is AppMigrationImportPause) {
                set(step, to: .failed)
                AppMigrationHaptics.stepFailed()
            }
            throw error
        }
    }

    private func set(_ step: AppMigrationImportStep, to state: AppMigrationStepState) {
        withAnimation { stepStates[step] = state }
    }

    private func pace() async {
        try? await Task.sleep(nanoseconds: UInt64(Self.minimumStepDuration * 1_000_000_000))
    }
}

extension AppMigrationImportViewModel {
    /// Asks the app being replaced for the slice after the one just stored. The store is the source
    /// of truth for what is missing, so a retried round trip cannot skip a slice.
    private func requestNextChunk() {
        let received = AppMigrationChunkStore.receivedIndices(forSession: chunk.sessionID)
        guard let missing = (0 ..< chunk.total).first(where: { !received.contains($0) }) else { return }

        set(.reading, to: .running)
        transfer = .init(completed: received.count, total: chunk.total)
        AppMigrationHaptics.transferAdvanced()

        guard let url = AppMigrationLink.continueURL(sessionID: chunk.sessionID, nextIndex: missing) else {
            phase = .failed(message: AppMigrationCodingError.malformedPayload.localizedDescription)
            return
        }
        Current.Log.info("Asking the previous app for chunk \(missing + 1)/\(chunk.total)")
        UIApplication.shared.open(url, options: [:]) { opened in
            guard !opened else { return }
            Current.Log.error("Could not reach the previous app for the next migration chunk")
        }
    }
}
