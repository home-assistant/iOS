import Shared
import SwiftUI
import UIKit

final class CameraOverlayPresenter {
    static let shared = CameraOverlayPresenter()

    struct Camera: Equatable {
        let entityId: String
        let serverIdentifier: Identifier<Server>
    }

    private(set) var displayedCamera: Camera?
    private weak var overlayController: UIViewController?
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

        let controller = CameraPlayerView(
            server: server,
            cameraEntityId: entityId,
            cameraName: cameraName,
            onCameraChange: overlayDidSwitchCamera(to:)
        )
        .embeddedInHostingController { CameraOverlayHostingController(rootView: $0) }
        controller.onAppear = { [weak self, weak controller] in
            guard let controller else { return }
            self?.overlayDidAppear(controller)
        }
        controller.onDismiss = { [weak self, weak controller] in
            guard let controller else { return }
            self?.overlayDidDisappear(controller)
        }
        controller.modalPresentationStyle = .overFullScreen

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
    func overlayDidAppear(_ controller: UIViewController) {
        guard controller === overlayController else { return }
        isPresenting = false
        guard hideWhenPresented else { return }
        hideWhenPresented = false
        isDismissing = true
        dismissDirectly(controller)
    }

    /// Called by the hosting controller when the overlay has been dismissed.
    func overlayDidDisappear(_ controller: UIViewController) {
        // Only the overlay on record matters: a replaced one going away must not clear its successor.
        guard controller === overlayController else { return }
        clearState()
    }

    /// Called when the picker inside the overlay switches to another camera, so a later show command for
    /// that camera is ignored and one for the camera it replaced is not.
    func overlayDidSwitchCamera(to entityId: String) {
        guard overlayController != nil, let serverIdentifier = displayedCamera?.serverIdentifier else { return }
        displayedCamera = Camera(entityId: entityId, serverIdentifier: serverIdentifier)
    }

    private func dismissDirectly(_ controller: UIViewController) {
        (controller.presentingViewController ?? controller).dismiss(animated: true) { [weak self] in
            self?.dismissalDidFinish()
        }
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
