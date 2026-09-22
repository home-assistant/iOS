import Combine
import Foundation
import Shared

/// Whether the web frontend's top bar currently offers a back action, and whether we are the ones
/// who should draw it.
///
/// With `hasNativeBackButton` in its external config, the frontend stops drawing its own back
/// arrow and instead reports `back_button/show` and `back_button/hide` over the bus. We draw the
/// button and send `back_button/pressed` back, so the navigation itself stays the frontend's.
final class NativeBackButtonState: ObservableObject {
    static let shared = NativeBackButtonState()

    /// Whether the frontend's window is on a device with a hinge — the iPhone Duo today. Fed by
    /// `onHingeChange`, whose context carries no hinge at all on everything else.
    @Published private(set) var hasHinge = false

    @Published private(set) var isVisible = false

    /// The value `config/get` last handed the frontend, or nil before it ever asked.
    private var reportedSupport: Bool?

    /// Only a hinged device takes the back button over, and only in the native tab bar layout,
    /// which is the one that gives us a toolbar to put it in.
    var isSupported: Bool {
        hasHinge && AppLabsFeature.iosNativeTabBar.isEnabled
    }

    /// Answers `hasNativeBackButton` and remembers the answer, so we can tell later whether the
    /// frontend is running on a stale one.
    func reportSupport() -> Bool {
        let supported = isSupported
        reportedSupport = supported
        return supported
    }

    /// True when the frontend was told something that no longer holds. It reads the external
    /// config once per page load, so only a fresh web view picks the new value up.
    var isFrontendReportStale: Bool {
        guard let reportedSupport else { return false }
        return reportedSupport != isSupported
    }

    func hingeAvailabilityChanged(to hasHinge: Bool) {
        guard hasHinge != self.hasHinge else { return }
        self.hasHinge = hasHinge
        if !isSupported {
            isVisible = false
        }
    }

    func show() {
        isVisible = true
    }

    func hide() {
        isVisible = false
    }

    /// A new page load leaves the frontend with nothing registered, so the button goes away until
    /// the reloaded frontend asks for it again.
    func reset() {
        isVisible = false
    }
}
