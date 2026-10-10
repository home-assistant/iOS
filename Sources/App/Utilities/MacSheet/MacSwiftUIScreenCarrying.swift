#if os(macOS)
import SwiftUI

/// A controller whose whole content is a SwiftUI screen.
///
/// The app hands such controllers to AppKit code to present, the same way it hands a `UIHostingController`
/// to UIKit on iOS. AppKit can put one in a sheet, but SwiftUI's `dismiss` action does nothing there, and
/// most screens close themselves with it. So the presenter takes the screen back out of the controller
/// and shows it in a sheet SwiftUI owns; see `NSViewController.presentSheet(_:)`.
protocol MacSwiftUIScreenCarrying: NSViewController {
    var carriedScreen: AnyView { get }
}

extension NSHostingController: MacSwiftUIScreenCarrying {
    var carriedScreen: AnyView {
        AnyView(rootView)
    }
}
#endif
