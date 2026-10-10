#if !os(macOS)
import SwiftUI
import UIKit

/// Hosts the camera overlay and tells the presenter when it comes on screen and when it is really dismissed.
///
/// SwiftUI's `onDisappear` fires for anything that takes the hosted view off screen, including another
/// controller presented full screen over it, so the presenter would forget a camera that was still on
/// display and then ignore `kiosk_hide_camera` for it. UIKit's dismissal flags tell the two apart.
final class CameraOverlayHostingController: UIHostingController<AnyView> {
    var onAppear: (() -> Void)?
    var onDismiss: (() -> Void)?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onAppear?()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isBeingDismissed || presentingViewController == nil else { return }
        onDismiss?()
    }
}
#endif
