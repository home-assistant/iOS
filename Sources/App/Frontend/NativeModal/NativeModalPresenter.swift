import Foundation
import Shared
import SwiftUI
import UIKit

/// Shows a frontend route in a modal of its own, in place of a dialog the frontend would draw.
///
/// The frontend sends `modal/open` with the route to show once the app reports `hasNativeModal`.
/// The modal hosts a second web view on that route; its close button sends `modal/close`, which the
/// modal's own controller answers by dismissing itself (see `WebViewController.closeNativeModal()`).
/// A link out of the page arrives as `modal/navigate`: the modal is dismissed and the frontend
/// underneath is sent to the destination over the bus.
///
/// The modal's chrome is SwiftUI (`NativeModalView`): a standard navigation bar showing what the
/// page's own header would. The title and breadcrumb come with `modal/open`; the buttons and menu,
/// and every later change, with `modal/header` from the modal's own frontend, which answers a tap
/// sent back as `modal/action` (see `NativeModalHeader`). The page leaves its own header out (the
/// app reports `hasNativeModal`). UIKit is kept to the web view.
///
/// A page inside a modal can ask for one of its own: each web view has its own presenter, so modals
/// stack, and a link out of any of them dismisses the stack and lands on the main frontend.
///
/// Booting a frontend is the expensive part, so the modal is kept after it is dismissed and shown
/// again for the next route with a page change over the bus. With the feature on, one is booted in
/// the background as soon as the main frontend has loaded, so the first modal opens as fast as the
/// next. The kept modal is a whole second frontend, so it goes under memory pressure.
@MainActor
final class NativeModalPresenter {
    /// Builds the modal's controller; tests inject one whose web view never loads.
    typealias ControllerFactory = @MainActor @Sendable (Server, WebViewControllerRole) -> WebViewController

    /// The SwiftUI modal around the web view; this is what gets presented.
    typealias Container = UIHostingController<NativeModalView<NativeModalWebView>>

    /// The modal kept for the next route, or nil until the first one is needed.
    private(set) var sheet: WebViewController?
    private(set) var container: Container?
    /// What the modal's bar and loader show.
    private(set) lazy var model = NativeModalModel()
    /// A route asked for while the modal's frontend was still booting; shown once it has loaded.
    private(set) var pendingPath: String?

    private nonisolated let makeController: ControllerFactory
    /// Clears what the frontend underneath carried for Siri, set for each presentation.
    private var dismissHandler: (() -> Void)?
    /// The entity the page inside is showing, as it last reported it.
    private var onscreenEntityId: String?
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

    /// Boots a modal off screen so the first one does not pay for the frontend's start.
    func prewarm(from host: WebViewControllerProtocol) {
        guard sheet == nil else { return }
        Current.Log.info("Booting a native modal in the background")
        let sheet = makeSheet(host: host, path: nil)
        sheet.loadActiveURLIfNeeded()
        self.sheet = sheet
    }

    /// `title` and `subtitle` are what the page's own header would show; without a title the bar
    /// names the route.
    func present(
        path: String,
        title: String? = nil,
        subtitle: String? = nil,
        size: NativeModalSize = .full,
        from host: WebViewControllerProtocol
    ) {
        Current.Log.info("Presenting a native modal at \(path)")

        let sheet: WebViewController
        if let kept = self.sheet, kept.server.identifier == host.server.identifier {
            sheet = kept
            show(path: path, in: sheet)
        } else {
            sheet = makeSheet(host: host, path: path)
            self.sheet = sheet
        }
        guard let container else { return }
        model.title = title ?? path
        model.subtitle = subtitle
        Self.configurePresentation(of: container, size: size)

        dismissHandler = { [weak self, weak host] in
            guard let self, let onscreenEntityId else { return }
            host?.clearOnscreenEntity(entityId: onscreenEntityId)
            self.onscreenEntityId = nil
        }
        // A link out is for the app's own frontend, not for whatever presented this modal. A modal
        // opened from inside another one hands the path up, dismissing each modal on the way, so the
        // destination always lands on the main frontend with nothing left over it.
        sheet.onNativeModalNavigation = { [weak host] path in
            guard let host else { return }
            if host.role.isMainFrontend {
                host.webViewExternalMessageHandler.sendExternalBusCommandWithRetry(
                    command: .navigate,
                    payload: ["path": path]
                )
            } else {
                host.relayNativeModalNavigation(path: path)
            }
        }

        if container.presentingViewController == nil {
            host.presentOverlayController(controller: container, animated: true)
        }
    }

    /// Drops the kept modal unless it is on screen. A second frontend is the first thing to give up
    /// when memory is short, and the next modal simply boots one again.
    func discardSheetIfHidden() {
        guard let container, container.presentingViewController == nil else { return }
        Current.Log.info("Discarding the kept native modal")
        self.container = nil
        sheet = nil
        pendingPath = nil
    }

    /// The modal has left the screen, however it was dismissed.
    func sheetDidDisappear() {
        dismissHandler?()
        dismissHandler = nil
    }

    /// How much room the frontend asked for. Set before each presentation, since the same modal
    /// serves every route in turn. The grabber only appears when there is a second detent to drag to.
    static func configurePresentation(
        of controller: UIViewController,
        size: NativeModalSize,
        animated: Bool = false
    ) {
        guard let sheet = controller.sheetPresentationController else { return }
        let apply = {
            let compact = size == .compact
            sheet.detents = compact ? [.medium(), .large()] : [.large()]
            sheet.selectedDetentIdentifier = compact ? .medium : .large
            sheet.prefersGrabberVisible = compact
        }
        if animated {
            sheet.animateChanges(apply)
        } else {
            apply()
        }
    }

    private func makeSheet(host: WebViewControllerProtocol, path: String?) -> WebViewController {
        let sheet = makeController(host.server, .nativeModal(path: path))
        // Building the web view now lets it start before the presentation animation does.
        sheet.loadViewIfNeeded()
        model.isLoading = true
        sheet.onNativeModalReady = { [weak self, weak sheet] in
            guard let self, let sheet else { return }
            model.isLoading = false
            guard let pendingPath else { return }
            self.pendingPath = nil
            navigate(to: pendingPath, in: sheet)
        }
        // The bar follows the page's own header; a dialog opened inside it needs the whole screen,
        // so the modal grows under it.
        sheet.onNativeModalUpdate = { [weak self] update in
            guard let self else { return }
            if let header = update.header {
                model.apply(header)
            }
            if let size = update.size, let container {
                Self.configurePresentation(of: container, size: size, animated: true)
            }
        }
        // Siri resolves "this" against the entity on screen. The modal publishes no activity of its
        // own, so the frontend underneath carries whatever the page inside reports, and drops it
        // when the modal goes.
        sheet.onNativeModalOnscreenEntity = { [weak self, weak host] entityId in
            guard let self, let host else { return }
            if let onscreenEntityId, onscreenEntityId != entityId {
                host.clearOnscreenEntity(entityId: onscreenEntityId)
            }
            onscreenEntityId = entityId
            if let entityId {
                host.setOnscreenEntity(entityId: entityId)
            }
        }
        container = makeContainer(around: sheet)
        observeMemoryWarnings()
        return sheet
    }

    private func makeContainer(around sheet: WebViewController) -> Container {
        let view = NativeModalView(
            model: model,
            onClose: { [weak self] in self?.container?.dismiss(animated: true) },
            onAction: { [weak self] id in self?.performHeaderAction(id) },
            onDisappear: { [weak self] in self?.sheetDidDisappear() }
        ) {
            NativeModalWebView(controller: sheet)
        }
        return UIHostingController(rootView: view)
    }

    /// A tap on the bar goes to the modal's frontend, which does what its own button would have.
    func performHeaderAction(_ id: String) {
        guard let sheet else { return }
        sheet.webViewExternalMessageHandler.sendExternalBusCommandWithRetry(
            command: .modalAction,
            payload: ["id": id]
        )
    }

    /// A booted modal changes page over the bus; one still booting keeps the loader up and is told
    /// which route once its frontend is up.
    private func show(path: String, in sheet: WebViewController) {
        if sheet.connectionState.isReadyForDisplay {
            navigate(to: path, in: sheet)
        } else {
            pendingPath = path
            model.isLoading = true
        }
    }

    private func navigate(to path: String, in sheet: WebViewController) {
        sheet.webViewExternalMessageHandler.sendExternalBusCommandWithRetry(
            command: .navigate,
            payload: ["path": path]
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
