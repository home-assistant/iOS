import Shared
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension ApplicationState {
    /// The state the app is in right now. A Mac app is never in the background: it is either frontmost
    /// or it is not. Read on the main thread.
    static var current: ApplicationState {
        #if os(macOS)
        NSApplication.shared.isActive ? .active : .inactive
        #else
        UIApplication.shared.applicationState
        #endif
    }
}
