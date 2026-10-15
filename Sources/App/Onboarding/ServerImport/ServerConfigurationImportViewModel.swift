import Combine
import Foundation
import Shared
import SwiftUI

/// Drives the confirmation screen: it holds the decoded document, classifies it for display, runs the
/// import when the user confirms, shows the results, and — only when the user asks for it on the
/// results screen — hands the token-less servers on to guided sign-in.
@MainActor
final class ServerConfigurationImportViewModel: ObservableObject {
    enum Phase: Equatable {
        case confirming
        case importing
        case finished(Summary)
    }

    struct Summary: Equatable {
        let added: Int
        let skipped: Int
        let failed: Int
        let guidedRemaining: Int
    }

    /// What the host does once the screen is gone.
    struct Completion: Equatable {
        /// Servers to walk through guided sign-in, in order. Empty unless the user chose to continue.
        let guidedServers: [ServerConfigurationImport.ServerEntry]
        /// True when the app had no servers before this import and now has at least one, so the
        /// first-run onboarding the app was showing is over.
        let completesFirstRun: Bool
    }

    @Published private(set) var phase: Phase = .confirming
    @Published private(set) var outcomes: [ServerConfigurationImport.ServerOutcome]

    let document: ServerConfigurationImport.Document
    private let runner: ServerConfigurationImportRunner

    /// Asks the host to take the screen down. Everything that follows happens in `didDismiss()`, which
    /// also covers the screen going away some other way.
    var onRequestDismiss: (() -> Void)?
    /// Called once, after the screen is gone, when an import ran. Not called if the user cancelled
    /// before confirming.
    var onCompletion: ((Completion) -> Void)?
    /// Called when the import starts and stops running, so the host can block a swipe-to-dismiss
    /// at the presentation level too.
    var onImportingChanged: ((Bool) -> Void)?

    private var runTask: Task<Void, Never>?
    private var runSummary: ServerConfigurationImportRunner.Summary?
    private var hadNoServersBeforeImport = false
    private var continuesToGuidedSignIn = false
    private var isDismissed = false
    private var hasReportedCompletion = false

    init(
        document: ServerConfigurationImport.Document,
        runner: ServerConfigurationImportRunner = ServerConfigurationImportRunner()
    ) {
        self.document = document
        self.runner = runner
        self.outcomes = ServerConfigurationImport.classify(
            document,
            existingServers: runner.persistence.existingServers
        )
    }

    var automaticCount: Int {
        outcomes.filter { $0.classification == .automatic }.count
    }

    var guidedCount: Int {
        outcomes.filter { $0.classification == .guided }.count
    }

    /// Whether confirming would actually do anything. A file of only duplicates has nothing to import.
    var hasActionableServers: Bool {
        automaticCount > 0 || guidedCount > 0
    }

    /// While the import runs, the screen can't be closed: a server that is half set up would otherwise
    /// be finished off behind the user's back.
    var isImporting: Bool {
        phase == .importing
    }

    var guidedServersRemaining: Int {
        runSummary?.guidedCount ?? 0
    }

    func confirm() {
        guard phase == .confirming else { return }
        phase = .importing
        onImportingChanged?(true)
        hadNoServersBeforeImport = runner.persistence.existingServers.isEmpty
        // Holds the view model until the run ends, even if the screen goes away meanwhile, so what the
        // run did is still reported.
        runTask = Task {
            let runSummary = await runner.run(document)
            applyRunSummary(runSummary)
        }
    }

    private func applyRunSummary(_ runSummary: ServerConfigurationImportRunner.Summary) {
        self.runSummary = runSummary
        outcomes = runSummary.outcomes
        phase = .finished(Summary(
            added: runSummary.addedCount,
            skipped: runSummary.skippedCount,
            failed: runSummary.failedCount,
            guidedRemaining: runSummary.guidedCount
        ))
        onImportingChanged?(false)

        if isDismissed {
            // The screen was taken down mid-run; report what was done without starting sign-in.
            reportCompletion()
        }
    }

    /// Closes the screen. Before confirming this cancels the import; after it, it ends the import
    /// without starting guided sign-in.
    func close() {
        guard !isImporting else { return }
        onRequestDismiss?()
    }

    /// The results screen's explicit go-ahead for signing in to the servers that need it.
    func continueToGuidedSignIn() {
        guard case .finished = phase else { return }
        continuesToGuidedSignIn = true
        onRequestDismiss?()
    }

    /// Called by the host once the screen is off screen, however it got there.
    func didDismiss() {
        guard !isDismissed else { return }
        isDismissed = true

        switch phase {
        case .confirming:
            break
        case .importing:
            // Only reachable if something else cleared the screen; stop before the next server is
            // written, and report once the run has wound down.
            runTask?.cancel()
        case .finished:
            reportCompletion()
        }
    }

    private func reportCompletion() {
        guard !hasReportedCompletion, let runSummary else { return }
        hasReportedCompletion = true
        onCompletion?(Completion(
            guidedServers: continuesToGuidedSignIn ? runSummary.guidedServers : [],
            completesFirstRun: hadNoServersBeforeImport && runSummary.addedCount > 0
        ))
    }
}
