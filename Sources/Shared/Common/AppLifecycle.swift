#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

#if !os(watchOS)
/// The application lifecycle notifications under one set of names for the iOS and macOS apps.
///
/// A Mac app has no background: it keeps running at full speed whether or not it is on screen, and is
/// never suspended. The background and foreground notifications are therefore never posted on macOS, and
/// whatever observes them there simply never runs.
public enum AppLifecycle {
    public static var didBecomeActiveNotification: Notification.Name {
        #if os(macOS)
        NSApplication.didBecomeActiveNotification
        #else
        UIApplication.didBecomeActiveNotification
        #endif
    }

    public static var willResignActiveNotification: Notification.Name {
        #if os(macOS)
        NSApplication.willResignActiveNotification
        #else
        UIApplication.willResignActiveNotification
        #endif
    }

    public static var didEnterBackgroundNotification: Notification.Name {
        #if os(macOS)
        Notification.Name("io.home-assistant.lifecycle.did-enter-background")
        #else
        UIApplication.didEnterBackgroundNotification
        #endif
    }

    public static var willEnterForegroundNotification: Notification.Name {
        #if os(macOS)
        Notification.Name("io.home-assistant.lifecycle.will-enter-foreground")
        #else
        UIApplication.willEnterForegroundNotification
        #endif
    }

    public static var willTerminateNotification: Notification.Name {
        #if os(macOS)
        NSApplication.willTerminateNotification
        #else
        UIApplication.willTerminateNotification
        #endif
    }
}
#endif
