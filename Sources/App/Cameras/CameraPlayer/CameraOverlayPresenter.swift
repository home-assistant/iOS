import Shared
import SwiftUI

final class CameraOverlayPresenter {
    static let shared = CameraOverlayPresenter()

    struct Camera: Equatable {
        let entityId: String
        let serverIdentifier: Identifier<Server>
    }

    #if os(macOS)
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
    private var isDismissing = false
    private var pendingShow: (() -> Void)?
    private let kiosk: KioskModeManager

    init(kiosk: KioskModeManager = Current.kiosk) {
        self.kiosk = kiosk
    }

    func isDisplaying(_ camera: Camera, on webViewController: WebViewControllerProtocol) -> Bool {
        guard displayedCamera == camera, let overlayController else { return false }
        return webViewController.overlayedController === overlayController
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

        guard !isDisplaying(camera, on: webViewController) else {
            Current.Log.info("Camera \(entityId) is already on display, ignoring show request")
            return
        }

        let player = CameraPlayerView(server: server, cameraEntityId: entityId, cameraName: cameraName)
            .onDisappear { [weak self] in
                self?.overlayDidDisappear(camera)
            }
        #if os(macOS)
        let controller = player
            .frame(
                minWidth: PlayerSize.minimum.width,
                idealWidth: PlayerSize.ideal.width,
                minHeight: PlayerSize.minimum.height,
                idealHeight: PlayerSize.ideal.height
            )
            .embeddedInHostingController()
        controller.preferredContentSize = PlayerSize.ideal
        #else
        let controller = player.embeddedInHostingController()
        controller.modalPresentationStyle = .overFullScreen
        #endif

        overlayController = controller
        displayedCamera = camera
        kiosk.setCameraOverlayVisible(true)
        webViewController.presentOverlayController(controller: controller, animated: true)
    }

    func hide(on webViewController: WebViewControllerProtocol) {
        precondition(Thread.isMainThread)
        guard let overlayController, webViewController.overlayedController === overlayController else {
            Current.Log.info("No camera is on display, ignoring hide request")
            clearState()
            return
        }

        isDismissing = true
        webViewController.dismissOverlayController(animated: true) { [weak self] in
            guard let self else { return }
            isDismissing = false
            clearState()
            let deferredShow = pendingShow
            pendingShow = nil
            deferredShow?()
        }
    }

    func overlayDidDisappear(_ camera: Camera) {
        guard displayedCamera == camera else { return }
        clearState()
    }

    private func clearState() {
        overlayController = nil
        displayedCamera = nil
        kiosk.setCameraOverlayVisible(false)
    }
}
