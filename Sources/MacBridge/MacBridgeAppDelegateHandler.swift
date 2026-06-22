import AppKit
import Foundation
import ObjectiveC.runtime

enum MacBridgeAppDelegateHandler {
    static let terminationWillBeginNotification: Notification.Name = .init("ha_terminationWillBegin")

    /// Invoked when the app is reopened (e.g. the Dock icon is clicked) with no visible windows.
    /// Returns `true` if it handled the reopen, which suppresses AppKit's default window creation.
    static var reopenHandler: (() -> Bool)?

    /// Implementation captured from the original `applicationShouldHandleReopen(_:hasVisibleWindows:)`
    /// (if the delegate had one, directly or inherited) so the swizzled method can call through to it.
    static var originalReopenIMP: IMP?

    static func swizzleAppDelegate() {
        guard !Bundle.main.isRunningInExtension else {
            // Don't try and swizzle the App Delegate in an extension; there won't be one.
            return
        }

        guard let delegate = NSApplication.shared.delegate else {
            // this likely only happens one time; the delegate is set after initial setup but before the runloop starts
            DispatchQueue.main.async {
                swizzleAppDelegate()
            }
            return
        }

        struct SwizzleMethods {
            let original: Selector
            let replacement: Selector
        }

        let allMethods: [SwizzleMethods] = [
            .init(
                original: #selector(NSApplicationDelegate.applicationShouldTerminate(_:)),
                replacement: #selector(NSObject.ha_applicationShouldTerminate(_:))
            ),
        ]

        let klass = type(of: delegate)

        for methods in allMethods {
            guard let original = class_getInstanceMethod(klass, methods.original),
                  let replacement = class_getInstanceMethod(klass, methods.replacement) else {
                fatalError("couldn't get methods for \(methods)")
            }

            method_exchangeImplementations(original, replacement)
        }

        installReopenSwizzle(on: klass)
    }

    /// `applicationShouldHandleReopen(_:hasVisibleWindows:)` is an *optional* `NSApplicationDelegate`
    /// method, so the Catalyst delegate may not implement it. Install our implementation safely rather
    /// than with `method_exchangeImplementations` (which `fatalError`s when the method is missing and
    /// would recurse if we added it with no original): capture any existing/inherited implementation to
    /// call through to, then add ours if absent or replace it if present.
    private static func installReopenSwizzle(on klass: AnyClass) {
        let originalSelector = #selector(NSApplicationDelegate.applicationShouldHandleReopen(_:hasVisibleWindows:))
        let replacementSelector = #selector(NSObject.ha_applicationShouldHandleReopen(_:hasVisibleWindows:))

        guard let replacement = class_getInstanceMethod(klass, replacementSelector) else { return }
        let replacementIMP = method_getImplementation(replacement)
        let typeEncoding = method_getTypeEncoding(replacement)

        // Capture any existing (possibly inherited) implementation up front so we can call through to it.
        originalReopenIMP = class_getInstanceMethod(klass, originalSelector).map(method_getImplementation)

        if !class_addMethod(klass, originalSelector, replacementIMP, typeEncoding) {
            // The class defines the method itself; replace it and capture its own implementation.
            originalReopenIMP = class_replaceMethod(klass, originalSelector, replacementIMP, typeEncoding)
        }
    }
}

private extension NSObject {
    @objc func ha_applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // we need to do this (a) long before actual termination, because we need to prevent it from happening
        // and (b) before we ask the NSUIApplicationDelegate what its response is, in case it doesn't delay otherwise
        // since we're going to (in effect) end up enqueueing background tasks as a result of this notification
        NotificationCenter.default.post(.init(name: MacBridgeAppDelegateHandler.terminationWillBeginNotification))

        // refers to the non-swizzled method
        return ha_applicationShouldTerminate(sender)
    }

    @objc func ha_applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        // Reopen with no visible windows (e.g. Dock icon click) — let the app decide what to do. This is
        // used to open Home Assistant in the browser when that preference is on; if the handler reports it
        // took over, suppress AppKit's default window creation by returning false.
        if !hasVisibleWindows, MacBridgeAppDelegateHandler.reopenHandler?() == true {
            return false
        }

        // Otherwise fall back to the delegate's original behaviour (if any), else allow the reopen.
        if let originalIMP = MacBridgeAppDelegateHandler.originalReopenIMP {
            typealias ReopenFunction = @convention(c) (NSObject, Selector, NSApplication, Bool) -> Bool
            let original = unsafeBitCast(originalIMP, to: ReopenFunction.self)
            return original(
                self,
                #selector(NSApplicationDelegate.applicationShouldHandleReopen(_:hasVisibleWindows:)),
                sender,
                hasVisibleWindows
            )
        }

        return true
    }
}
