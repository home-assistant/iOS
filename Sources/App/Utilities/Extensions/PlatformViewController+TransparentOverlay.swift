import Shared
#if os(macOS)
import AppKit
import ObjectiveC
#else
import UIKit
#endif

#if os(macOS)
private var sizesSheetToContentKey: UInt8 = 0
#endif

extension PlatformViewController {
    /// Sets the controller up to cover the screen with nothing of its own behind its content and to fade in,
    /// which is what a SwiftUI screen that draws its own card over the frontend needs on iOS. The Mac shows
    /// the same screen as a sheet on the window, made just large enough for that card.
    func presentsAsTransparentOverlay() {
        #if os(iOS)
        view.backgroundColor = .clear
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        #else
        sizesSheetToContent = true
        #endif
    }

    #if os(macOS)
    /// Whether the sheet this controller is presented in takes its size from the screen inside it, rather
    /// than a size of the presenter's choosing.
    private(set) var sizesSheetToContent: Bool {
        get { objc_getAssociatedObject(self, &sizesSheetToContentKey) as? Bool ?? false }
        set {
            objc_setAssociatedObject(self, &sizesSheetToContentKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    #endif
}
