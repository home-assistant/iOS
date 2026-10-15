import SwiftUI
import UIKit

/// Hosts a screen presented by the server import and reports, once, when it has really been dismissed
/// — by its own buttons, a swipe, or something else clearing the screen. A controller presented over
/// it doesn't count; UIKit's dismissal flags tell the two apart (as in `CameraOverlayHostingController`).
final class DismissalReportingHostingController: UIHostingController<AnyView> {
    var onDismiss: (() -> Void)?

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isBeingDismissed || presentingViewController == nil else { return }
        let onDismiss = onDismiss
        self.onDismiss = nil
        onDismiss?()
    }
}
