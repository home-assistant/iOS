#if os(macOS)
import AppKit
import SwiftUI

// The view-layer types the iOS and macOS apps each build on, under one name for the places that only pass
// them along: a coordinator handing a controller to present, a protocol naming the window a request
// came from. Code that does anything with the view itself is written per platform.
public typealias PlatformView = NSView
public typealias PlatformViewController = NSViewController
public typealias PlatformWindow = NSWindow
public typealias PlatformHostingController<Content: View> = NSHostingController<Content>
/// What a request is routed back to so it stays in the window it came from. iOS groups windows into
/// scenes; on the Mac every window stands on its own.
public typealias PlatformWindowScene = NSWindow

public extension NSWindow {
    /// A Mac window is its own scene, so code shared with iOS can ask a view for `window?.windowScene`
    /// on both platforms.
    var windowScene: NSWindow? { self }
}

#elseif os(iOS)
import SwiftUI
import UIKit

// The view-layer types the iOS and macOS apps each build on, under one name for the places that only pass
// them along: a coordinator handing a controller to present, a protocol naming the window a request
// came from. Code that does anything with the view itself is written per platform.
public typealias PlatformView = UIView
public typealias PlatformViewController = UIViewController
public typealias PlatformWindow = UIWindow
public typealias PlatformHostingController<Content: View> = UIHostingController<Content>
/// What a request is routed back to so it stays in the window it came from. iOS groups windows into
/// scenes; on the Mac every window stands on its own.
public typealias PlatformWindowScene = UIWindowScene
#endif
