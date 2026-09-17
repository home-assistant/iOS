import Foundation
import Shared
import UIKit

/// Shows an entity's details in a sheet of their own, in place of the frontend's more-info dialog.
///
/// The frontend sends `more_info/open` instead of opening its dialog once the app reports
/// `hasNativeMoreInfo`. The sheet hosts a second web view on the frontend's frameless `/more-info`
/// route; its close button sends `more_info/close`, which the sheet's own controller answers by
/// dismissing itself (see `WebViewController.closeStandaloneMoreInfo()`). A link out of the page
/// (device page, entity editor, related items) arrives as `more_info/navigate`: the sheet is
/// dismissed and the frontend underneath is sent to the destination over the bus.
///
/// Booting a frontend is the expensive part, so the sheet is kept after it is dismissed and shown
/// again for the next entity with a page change over the bus. With the feature on, one is booted
/// in the background as soon as the main frontend has loaded, so the first entity opens as fast as
/// the next. The kept sheet is a whole second frontend, so it goes under memory pressure.
@MainActor
final class StandaloneMoreInfoPresenter {
    /// Builds the sheet's controller; tests inject one whose web view never loads.
    typealias ControllerFactory = @MainActor @Sendable (Server, WebViewControllerRole) -> WebViewController

    /// The sheet kept for the next entity, or nil until the first one is needed.
    private(set) var sheet: WebViewController?
    /// An entity asked for while the sheet's frontend was still booting; shown once it has loaded.
    private(set) var pendingEntityId: String?

    private nonisolated let makeController: ControllerFactory
    private var memoryWarningObserver: NSObjectProtocol?

    nonisolated init(
        makeController: @escaping ControllerFactory = { @MainActor in WebViewController(server: $0, role: $1) }
    ) {
        self.makeController = makeController
    }

    deinit {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
    }

    /// Boots a sheet off screen so the first entity does not pay for the frontend's start.
    func prewarm(from host: WebViewControllerProtocol) {
        guard sheet == nil else { return }
        Current.Log.info("Booting a standalone more-info sheet in the background")
        let sheet = makeSheet(server: host.server, entityId: nil)
        sheet.loadActiveURLIfNeeded()
        self.sheet = sheet
    }

    func present(entityId: String, from host: WebViewControllerProtocol) {
        Current.Log.info("Presenting standalone more-info for \(entityId)")

        let sheet: WebViewController
        if let kept = self.sheet, kept.server.identifier == host.server.identifier {
            sheet = kept
            show(entityId: entityId, in: sheet)
        } else {
            sheet = makeSheet(server: host.server, entityId: entityId)
            self.sheet = sheet
        }
        Self.configurePresentation(of: sheet, entityId: entityId)

        // Siri resolves "this" against the entity on screen. The sheet publishes no activity of its
        // own, so the frontend underneath carries the entity while the sheet is up and drops it after.
        host.setOnscreenEntity(entityId: entityId)
        sheet.onDismiss = { [weak host] in
            host?.clearOnscreenEntity(entityId: entityId)
        }
        sheet.onStandaloneNavigation = { [weak host] path in
            host?.webViewExternalMessageHandler.sendExternalBusCommandWithRetry(
                command: .navigate,
                payload: ["path": path]
            )
        }

        if sheet.presentingViewController == nil {
            host.presentOverlayController(controller: sheet, animated: true)
        }
    }

    /// Drops the kept sheet unless it is on screen. A second frontend is the first thing to give up
    /// when memory is short, and the next entity simply boots one again.
    func discardSheetIfHidden() {
        guard let sheet, sheet.presentingViewController == nil else { return }
        Current.Log.info("Discarding the kept standalone more-info sheet")
        self.sheet = nil
        pendingEntityId = nil
    }

    /// A sensor's details fit half a screen; a light's controls need the whole of it. Set before each
    /// presentation, since the same sheet serves every entity in turn. The grabber only appears when
    /// there is a second detent to drag to.
    static func configurePresentation(of controller: UIViewController, entityId: String) {
        if Current.isCatalyst {
            controller.modalPresentationStyle = .formSheet
        } else if let sheet = controller.sheetPresentationController {
            let compact = prefersCompactSheet(entityId: entityId)
            sheet.detents = compact ? [.medium(), .large()] : [.large()]
            sheet.selectedDetentIdentifier = compact ? .medium : .large
            sheet.prefersGrabberVisible = compact
        }
    }

    /// Unknown domains are custom integrations whose details could be anything, so they get the room.
    nonisolated static func prefersCompactSheet(entityId: String) -> Bool {
        guard let domain = Domain(entityId: entityId) else { return false }
        return domain.prefersCompactMoreInfoSheet
    }

    private func makeSheet(server: Server, entityId: String?) -> WebViewController {
        let sheet = makeController(server, .standaloneMoreInfo(entityId: entityId))
        // Building the web view now lets it start before the presentation animation does.
        sheet.loadViewIfNeeded()
        sheet.onStandaloneFrontendLoaded = { [weak self, weak sheet] in
            guard let self, let sheet, let pendingEntityId else { return }
            self.pendingEntityId = nil
            navigate(to: pendingEntityId, in: sheet)
        }
        observeMemoryWarnings()
        return sheet
    }

    /// A booted sheet changes page over the bus; one still booting shows the loader and is told
    /// which entity once its frontend is up.
    private func show(entityId: String, in sheet: WebViewController) {
        if sheet.connectionState.isReadyForDisplay {
            navigate(to: entityId, in: sheet)
        } else {
            pendingEntityId = entityId
            sheet.showStandaloneLoadingIndicator()
        }
    }

    private func navigate(to entityId: String, in sheet: WebViewController) {
        sheet.webViewExternalMessageHandler.sendExternalBusCommandWithRetry(
            command: .navigate,
            payload: ["path": WebViewControllerRole.standaloneMoreInfoPath(entityId: entityId)]
        )
    }

    private func observeMemoryWarnings() {
        guard memoryWarningObserver == nil else { return }
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.discardSheetIfHidden()
            }
        }
    }
}
