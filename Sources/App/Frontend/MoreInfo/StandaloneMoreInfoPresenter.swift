import Foundation
import Shared
import SwiftUI
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
/// The sheet's chrome is SwiftUI (`StandaloneMoreInfoSheetView`): a standard navigation bar showing
/// what the frontend's header would. The name and breadcrumb come with `more_info/open`; the buttons
/// and menu, and every later change, with `more_info/header` from the sheet's own frontend, which
/// answers a tap sent back as `more_info/action` (see `StandaloneMoreInfoHeader`). The page leaves
/// its own header out (the app reports `hasNativeMoreInfoHeader`). UIKit is kept to the web view.
///
/// Booting a frontend is the expensive part, so the sheet is kept after it is dismissed and shown
/// again for the next entity with a page change over the bus. With the feature on, one is booted
/// in the background as soon as the main frontend has loaded, so the first entity opens as fast as
/// the next. The kept sheet is a whole second frontend, so it goes under memory pressure.
@MainActor
final class StandaloneMoreInfoPresenter {
    /// Builds the sheet's controller; tests inject one whose web view never loads.
    typealias ControllerFactory = @MainActor @Sendable (Server, WebViewControllerRole) -> WebViewController

    /// The SwiftUI sheet around the web view; this is what gets presented.
    typealias Container = UIHostingController<StandaloneMoreInfoSheetView<StandaloneMoreInfoWebView>>

    /// The sheet kept for the next entity, or nil until the first one is needed.
    private(set) var sheet: WebViewController?
    private(set) var container: Container?
    /// What the sheet's bar and loader show.
    private(set) lazy var model = StandaloneMoreInfoSheetModel()
    /// An entity asked for while the sheet's frontend was still booting; shown once it has loaded.
    private(set) var pendingEntityId: String?

    private nonisolated let makeController: ControllerFactory
    /// Clears the entity the frontend underneath carried for Siri, set for each presentation.
    private var dismissHandler: (() -> Void)?
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

    /// `title` and `subtitle` are what the frontend's more-info header would show; without them the
    /// bar names the entity by its id.
    func present(
        entityId: String,
        title: String? = nil,
        subtitle: String? = nil,
        from host: WebViewControllerProtocol
    ) {
        Current.Log.info("Presenting standalone more-info for \(entityId)")

        let sheet: WebViewController
        if let kept = self.sheet, kept.server.identifier == host.server.identifier {
            sheet = kept
            show(entityId: entityId, in: sheet)
        } else {
            sheet = makeSheet(server: host.server, entityId: entityId)
            self.sheet = sheet
        }
        guard let container else { return }
        model.title = title ?? entityId
        model.subtitle = subtitle
        Self.configurePresentation(of: container, entityId: entityId)

        // Siri resolves "this" against the entity on screen. The sheet publishes no activity of its
        // own, so the frontend underneath carries the entity while the sheet is up and drops it after.
        host.setOnscreenEntity(entityId: entityId)
        dismissHandler = { [weak host] in
            host?.clearOnscreenEntity(entityId: entityId)
        }
        sheet.onStandaloneNavigation = { [weak host] path in
            host?.webViewExternalMessageHandler.sendExternalBusCommandWithRetry(
                command: .navigate,
                payload: ["path": path]
            )
        }

        if container.presentingViewController == nil {
            host.presentOverlayController(controller: container, animated: true)
        }
    }

    /// Drops the kept sheet unless it is on screen. A second frontend is the first thing to give up
    /// when memory is short, and the next entity simply boots one again.
    func discardSheetIfHidden() {
        guard let container, container.presentingViewController == nil else { return }
        Current.Log.info("Discarding the kept standalone more-info sheet")
        self.container = nil
        sheet = nil
        pendingEntityId = nil
    }

    /// The sheet has left the screen, however it was dismissed.
    func sheetDidDisappear() {
        dismissHandler?()
        dismissHandler = nil
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
        model.isLoading = true
        sheet.onStandaloneFrontendLoaded = { [weak self, weak sheet] in
            guard let self, let sheet else { return }
            model.isLoading = false
            guard let pendingEntityId else { return }
            self.pendingEntityId = nil
            navigate(to: pendingEntityId, in: sheet)
        }
        sheet.onStandaloneHeaderChange = { [weak self] header in
            self?.model.apply(header)
        }
        container = makeContainer(around: sheet)
        observeMemoryWarnings()
        return sheet
    }

    private func makeContainer(around sheet: WebViewController) -> Container {
        let view = StandaloneMoreInfoSheetView(
            model: model,
            onClose: { [weak self] in self?.container?.dismiss(animated: true) },
            onAction: { [weak self] id in self?.performHeaderAction(id) },
            onDisappear: { [weak self] in self?.sheetDidDisappear() }
        ) {
            StandaloneMoreInfoWebView(controller: sheet)
        }
        return UIHostingController(rootView: view)
    }

    /// A tap on the bar goes to the sheet's frontend, which does what its own button would have.
    func performHeaderAction(_ id: String) {
        guard let sheet else { return }
        sheet.webViewExternalMessageHandler.sendExternalBusCommandWithRetry(
            command: .moreInfoAction,
            payload: ["id": id]
        )
    }

    /// A booted sheet changes page over the bus; one still booting keeps the loader up and is told
    /// which entity once its frontend is up.
    private func show(entityId: String, in sheet: WebViewController) {
        if sheet.connectionState.isReadyForDisplay {
            navigate(to: entityId, in: sheet)
        } else {
            pendingEntityId = entityId
            model.isLoading = true
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
