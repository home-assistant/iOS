import AppKit
import Foundation
import ObjectiveC.runtime

enum MacBridgeAppDelegateHandler {
    static let terminationWillBeginNotification: Notification.Name = .init("ha_terminationWillBegin")

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
}
