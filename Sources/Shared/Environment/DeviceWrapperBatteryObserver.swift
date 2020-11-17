import Foundation
#if canImport(IOKit)
import IOKit.ps
#endif
#if os(iOS)
import UIKit
#endif
#if os(watchOS)
import WatchKit
#endif

public protocol DeviceWrapperBatteryNotificationObserver: AnyObject {
    // We only observe state, because observing level is effectively the same as our periodic updating.
    func deviceBatteryStateDidChange(_ center: DeviceWrapperBatteryNotificationCenter)
}

public class DeviceWrapperBatteryNotificationCenter {
    private var observers = NSHashTable<AnyObject>(options: .weakMemory)

    public init() {
        #if canImport(IOKit)
        // We only observe state, because observing level is effectively
        // observing every 60 seconds, which is covered by periodic.
        addIOKitObserver(for: kIOPSNotifyPowerSource as CFString)
        #endif

        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        addObserver(for: UIDevice.batteryStateDidChangeNotification)
        #endif

        #if os(watchOS)
        // doesn't appear there are any notifications available for watchOS
        // so we do not turn on monitoring, either
        #endif
    }

    deinit {
        #if canImport(IOKit)
        CFNotificationCenterRemoveObserver(
            /* center */ CFNotificationCenterGetDarwinNotifyCenter(),
            /* observer */ Unmanaged.passUnretained(self).toOpaque(),
            /* notification name */ nil /* to remove all */,
            /* ignored for darwin; object */ nil
        )
        #endif

        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        #endif
    }

    public func register(observer: DeviceWrapperBatteryNotificationObserver) {
        observers.add(observer)
    }

    public func unregister(observer: DeviceWrapperBatteryNotificationObserver) {
        observers.remove(observer)
    }

    private func notify() {
        observers
            .allObjects
            .compactMap { $0 as? DeviceWrapperBatteryNotificationObserver }
            .forEach { $0.deviceBatteryStateDidChange(self) }
    }

    private func addObserver(for notification: Notification.Name) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(notificationDidFire(_:)),
            name: notification,
            object: nil
        )
    }

    @objc private func notificationDidFire(_ note: Notification) {
        Current.Log.info("battery updated from \(note.name)")
        notify()
    }

    #if canImport(IOKit)
    private func addIOKitObserver(for notificationName: CFString) {
        let callback: CFNotificationCallback = { _, observer, name, /* ignored */ _, /* ignored */ _ in
            // this block is a C block, which cannot weakly capture self, so we do the dance
            guard let observer = observer else {
                Current.Log.error("unexpected nil observer for battery sensor")
                return
            }

            let this = Unmanaged<DeviceWrapperBatteryNotificationCenter>.fromOpaque(observer).takeUnretainedValue()
            let loggableName = name?.rawValue as String? ?? "(unknown)"
            Current.Log.info("battery updated from \(loggableName)")
            this.notify()
        }

        CFNotificationCenterAddObserver(
            /* center */ CFNotificationCenterGetDarwinNotifyCenter(),
            /* observer */ Unmanaged.passUnretained(self).toOpaque(),
            /* callback */ callback,
            /* notification name */ notificationName,
            /* ignored for drawin; object */ nil,
            /* ignored for darwin; suspension behavior */ .coalesce
        )
    }
    #endif
}
