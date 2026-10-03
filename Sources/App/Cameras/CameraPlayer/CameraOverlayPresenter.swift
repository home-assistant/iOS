import Shared
import SwiftUI

final class CameraOverlayPresenter {
    static let shared = CameraOverlayPresenter()

    struct Camera: Equatable {
        let entityId: String
        let serverIdentifier: Identifier<Server>
    }

    #if os(macOS)
    /// Carries the hosted view's appearance callbacks to the controller that is created after the view.
    private final class MacOverlayLifecycle {
        var onAppear: (() -> Void)?
        var onDisappear: (() -> Void)?
    }

    /// Presented on a Mac, the player takes its size from its content instead of from a screen it
    /// covers. It is happy at any size, so it is given one to open at and a floor that keeps its
    /// controls usable.
    private enum PlayerSize {
        static let minimum = CGSize(width: 480, height: 270)
        static let ideal = CGSize(width: 960, height: 540)
    }
    #endif

    private(set) var displayedCamera: Camera?
    private weak var overlayController: PlatformViewController?
    /// Set from `show` until the overlay has appeared: the web view presents on a later turn of the main
    /// queue, so for a moment the overlay exists without being on screen.
    private var isPresenting = false
    private var hideWhenPresented = false
    private var isDismissing = false
    private var pendingShow: (() -> Void)?
    private let kiosk: KioskModeManager

    init(kiosk: KioskModeManager = Current.kiosk) {
        self.kiosk = kiosk
    }

    /// Whether `camera` is on display, or about to be while its presentation is still in flight.
    ///
    /// Decided from the presenter's own record rather than from what the web view reports as its presented
    /// controller: that comparison is false while the presentation is pending, and whenever the web view
    /// controller has been replaced underneath the overlay, which made a repeated show command tear the
    /// camera down and present it again.
    func isDisplaying(_ camera: Camera) -> Bool {
        displayedCamera == camera && overlayController != nil && !isDismissing
    }

    func show(
        entityId: String,
        server: Server,
        cameraName: String? = nil,
        on webViewController: WebViewControllerProtocol
    ) {
        precondition(Thread.isMainThread)
        let camera = Camera(entityId: entityId, serverIdentifier: server.identifier)

        if isDismissing {
            if webViewController.overlayedController != nil {
                Current.Log.info("Camera \(entityId) requested while another overlay is dismissing, deferring")
                pendingShow = { [weak self, weak webViewController] in
                    guard let webViewController else { return }
                    self?.show(entityId: entityId, server: server, cameraName: cameraName, on: webViewController)
                }
                return
            }
            isDismissing = false
        }

        guard !isDisplaying(camera) else {
            Current.Log.info("Camera \(entityId) is already on display, ignoring show request")
            return
        }

        // This show supersedes anything still waiting on an earlier dismissal; left in place, that stale
        // request would present its camera when this overlay is eventually dismissed.
        pendingShow = nil

        let player = CameraPlayerView(
            server: server,
            cameraEntityId: entityId,
            cameraName: cameraName,
            onCameraChange: { [weak self] entityId in
                self?.overlayDidSwitchCamera(to: entityId, on: server)
            }
        )
        #if os(macOS)
        // The Mac shows the player in a sheet SwiftUI owns, which hosts the view again outside this
        // controller, so the view reports its own appearance; a sheet is never covered by another one.
        let lifecycle = MacOverlayLifecycle()
        let controller = player
            .frame(
                minWidth: PlayerSize.minimum.width,
                idealWidth: PlayerSize.ideal.width,
                minHeight: PlayerSize.minimum.height,
                idealHeight: PlayerSize.ideal.height
            )
            .onAppear { lifecycle.onAppear?() }
            .onDisappear { lifecycle.onDisappear?() }
            .embeddedInHostingController()
        controller.preferredContentSize = PlayerSize.ideal
        lifecycle.onAppear = { [weak self, weak controller] in
            guard let controller else { return }
            self?.overlayDidAppear(controller)
        }
        lifecycle.onDisappear = { [weak self, weak controller] in
            guard let controller else { return }
            self?.overlayDidDisappear(controller)
        }
        #else
        let controller = player.embeddedInHostingController { CameraOverlayHostingController(rootView: $0) }
        controller.onAppear = { [weak self, weak controller] in
            guard let controller else { return }
            self?.overlayDidAppear(controller)
        }
        controller.onDismiss = { [weak self, weak controller] in
            guard let controller else { return }
            self?.overlayDidDisappear(controller)
        }
        controller.modalPresentationStyle = .overFullScreen
        #endif

        overlayController = controller
        displayedCamera = camera
        isPresenting = true
        hideWhenPresented = false
        kiosk.setCameraOverlayVisible(true)
        webViewController.presentOverlayController(controller: controller, animated: true)
    }

    func hide(on webViewController: WebViewControllerProtocol) {
        precondition(Thread.isMainThread)
        guard let overlayController else {
            Current.Log.info("No camera is on display, ignoring hide request")
            clearState()
            return
        }

        if isPresenting {
            // Not on screen yet; it comes down as soon as it has appeared (see `overlayDidAppear`).
            Current.Log.info("Camera overlay is still being presented, hiding it once it has appeared")
            hideWhenPresented = true
            return
        }

        isDismissing = true
        if webViewController.overlayedController === overlayController {
            webViewController.dismissOverlayController(animated: true) { [weak self] in
                self?.dismissalDidFinish()
            }
        } else {
            // The web view no longer counts the overlay as its own (it was replaced underneath, or something
            // was presented between them), yet the camera is still on screen: take it down directly rather
            // than treating the command as having nothing to do.
            Current.Log.info("Camera overlay is not the web view's presented controller, dismissing it directly")
            dismissDirectly(overlayController)
        }
    }

    /// Called by the hosting controller once the overlay is on screen.
    func overlayDidAppear(_ controller: PlatformViewController) {
        guard controller === overlayController else { return }
        isPresenting = false
        guard hideWhenPresented else { return }
        hideWhenPresented = false
        isDismissing = true
        dismissDirectly(controller)
    }

    /// Called by the hosting controller when the overlay has been dismissed.
    func overlayDidDisappear(_ controller: PlatformViewController) {
        // Only the overlay on record matters: a replaced one going away must not clear its successor.
        guard controller === overlayController else { return }
        clearState()
    }

    /// Called when the picker inside the overlay switches to another camera, so a later show command for
    /// that camera is ignored and one for the camera it replaced is not.
    func overlayDidSwitchCamera(to entityId: String, on server: Server) {
        guard overlayController != nil else { return }
        displayedCamera = Camera(entityId: entityId, serverIdentifier: server.identifier)
    }

    private func dismissDirectly(_ controller: PlatformViewController) {
        #if os(macOS)
        controller.dismissSheet()
        dismissalDidFinish()
        #else
        (controller.presentingViewController ?? controller).dismiss(animated: true) { [weak self] in
            self?.dismissalDidFinish()
        }
        #endif
    }

    private func dismissalDidFinish() {
        isDismissing = false
        clearState()
        let deferredShow = pendingShow
        pendingShow = nil
        deferredShow?()
    }

    private func clearState() {
        overlayController = nil
        displayedCamera = nil
        isPresenting = false
        hideWhenPresented = false
        kiosk.setCameraOverlayVisible(false)
    }
}
