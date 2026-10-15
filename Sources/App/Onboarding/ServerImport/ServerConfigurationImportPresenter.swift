import Foundation
import Shared
import SwiftUI
import UIKit

/// Routes an opened server-configuration document into the confirmation screen and, when the user
/// asks for it on the results screen, into guided sign-in for any token-less servers. Kept separate
/// from `IncomingURLHandler` so the file-open plumbing there stays a thin dispatch and the import UX
/// lives with the rest of the import code.
@MainActor
enum ServerConfigurationImportPresenter {
    /// Decodes the file and, on success, presents the confirmation screen over whatever is on screen
    /// (the web view, or first-run onboarding on a fresh install).
    /// A decode failure surfaces as an alert rather than silently doing nothing.
    static func present(fileURL url: URL, coordinator: AppCoordinator) {
        // Decoding reads the whole file, so iOS's copy of an externally opened file isn't needed after.
        defer { removeInboxCopy(of: url) }

        let document: ServerConfigurationImport.Document
        do {
            document = try ServerConfigurationImport.decode(fileURL: url)
        } catch {
            Current.Log.error("Server configuration import rejected \(url.lastPathComponent): \(error)")
            presentError(error, coordinator: coordinator)
            return
        }

        Current.Log.info("Server configuration import: presenting \(document.servers.count) server(s)")
        presentConfirmation(document: document, coordinator: coordinator)
    }

    private static func presentConfirmation(
        document: ServerConfigurationImport.Document,
        coordinator: AppCoordinator
    ) {
        let viewModel = ServerConfigurationImportViewModel(document: document)
        let controller = ServerConfigurationImportView(viewModel: viewModel).embeddedInHostingController {
            DismissalReportingHostingController(rootView: $0)
        }

        viewModel.onRequestDismiss = { [weak controller] in
            controller?.dismiss(animated: true)
        }
        viewModel.onImportingChanged = { [weak controller] isImporting in
            controller?.isModalInPresentation = isImporting
        }
        // Whatever follows the import runs once its screen is fully gone, so nothing is presented on
        // a controller that is tearing down.
        controller.onDismiss = { [weak viewModel] in
            viewModel?.didDismiss()
        }
        viewModel.onCompletion = { completion in
            importDidComplete(completion, coordinator: coordinator)
        }

        coordinator.dismissPresentedContent {
            coordinator.present(controller, animated: true, completion: nil)
        }
    }

    /// What follows a finished import, once its screen is gone. Internal for tests.
    static func importDidComplete(
        _ completion: ServerConfigurationImportViewModel.Completion,
        coordinator: AppCoordinator
    ) {
        if completion.completesFirstRun {
            // Adding servers doesn't move the app off the first-run onboarding screen by itself;
            // finishing onboarding is what does (`OnboardingStateObservable` shows the web view on
            // `.complete`). Only on first run: with servers already set up, `.complete` would switch
            // the user to the first server.
            Current.Log.info("Server configuration import: first server added, completing first-run onboarding")
            Current.onboardingObservation.complete()
        }

        guard !completion.guidedServers.isEmpty else { return }
        // Let the first-run transition land before onboarding is presented over it.
        DispatchQueue.main.async {
            startGuidedSignIn(servers: completion.guidedServers, coordinator: coordinator)
        }
    }

    /// Drives the normal onboarding flow for every token-less server in sequence, URL pre-filled,
    /// advancing to the next one as each finishes (see `ServerConfigurationGuidedSignIn`).
    private static func startGuidedSignIn(
        servers: [ServerConfigurationImport.ServerEntry],
        coordinator: AppCoordinator
    ) {
        Current.Log.info("Server configuration import: starting guided sign-in for \(servers.count) server(s)")
        ServerConfigurationGuidedSignIn(servers: servers, coordinator: coordinator).start()
    }

    private static func removeInboxCopy(of url: URL) {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              ServerConfigurationImport.isInboxCopy(url, documentsDirectory: documents) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Current.Log.error("Server configuration import could not remove \(url.lastPathComponent): \(error)")
        }
    }

    private static func presentError(_ error: Error, coordinator: AppCoordinator) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let alert = UIAlertController(
            title: L10n.errorLabel,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default))
        coordinator.present(alert, animated: true, completion: nil)
    }
}
