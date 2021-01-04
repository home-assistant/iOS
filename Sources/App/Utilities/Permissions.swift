//
//  Permissions.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/22/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import Lottie
import UserNotifications
import CoreMotion
import CoreLocation
import Shared

public enum PermissionStatus {
    case notDetermined
    case denied
    case authorized
    case authorizedWhenInUse // CLAuthorizationStatus only
    case restricted // Used if UNAuthorizationStatus is .provisional
    case unknown

    var description: String {
        switch self {
        case .notDetermined:
            return "Not determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .authorizedWhenInUse:
            return "Authorized when in use"
        case .unknown:
            return "Unknown"
        }
    }
}

extension CLAuthorizationStatus {
    var genericStatus: PermissionStatus {
        switch self {
        case .notDetermined:
            return PermissionStatus.notDetermined
        case .restricted:
            return PermissionStatus.restricted
        case .denied:
            return PermissionStatus.denied
        case .authorizedAlways:
            return PermissionStatus.authorized
        case .authorizedWhenInUse:
            return PermissionStatus.authorizedWhenInUse
        @unknown default:
            Current.Log.warning("Caught unknown CLAuthorizationStatus \(self), returning PermissionStatus.unknown")
            return PermissionStatus.unknown
        }
    }
}

extension CMAuthorizationStatus {
    var genericStatus: PermissionStatus {
        switch self {
        case .notDetermined:
            return PermissionStatus.notDetermined
        case .restricted:
            return PermissionStatus.restricted
        case .denied:
            return PermissionStatus.denied
        case .authorized:
            return PermissionStatus.authorized
        @unknown default:
            Current.Log.warning("Caught unknown CMAuthorizationStatus \(self), returning PermissionStatus.unknown")
            return PermissionStatus.unknown
        }
    }
}

extension UNAuthorizationStatus {
    var genericStatus: PermissionStatus {
        switch self {
        case .notDetermined:
            return PermissionStatus.notDetermined
        case .provisional:
            return PermissionStatus.restricted
        case .denied:
            return PermissionStatus.denied
        #if compiler(>=5.3)
        case .ephemeral:
            return PermissionStatus.authorized
        #endif
        case .authorized:
            return PermissionStatus.authorized
        @unknown default:
            Current.Log.warning("Caught unknown UNAuthorizationStatus \(self), returning PermissionStatus.unknown")
            return PermissionStatus.unknown
        }
    }
}

public enum PermissionType: Int {
    case location = 0
    case motion = 1
    case notification = 2

    var title: String {
        switch self {
        case .location:
            return "Location"
        case .motion:
            return "Motion & Pedometer"
        case .notification:
            return "Notifications"
        }
    }

    var description: String {
        switch self {
        case .location:
            return "Enable location services to allow presence detection automations."
        case .motion:
            return "Allow motion activity and pedometer data to be sent to Home Assistant"
        case .notification:
            return "Allow push notifications to be sent from your Home Assistant"
        }
    }

    var animation: Animation? {
        switch self {
        case .location:
            return Animation.named("location")
        case .notification:
            return Animation.named("notification")
        case .motion:
            return Animation.named("motion")
        }
    }

    var status: PermissionStatus {
        switch self {
        case .location:
            return CLLocationManager.authorizationStatus().genericStatus
        case .motion:
            return CMMotionActivityManager.authorizationStatus().genericStatus
        case .notification:
            guard let authorizationStatus = self.fetchNotificationsAuthorizationStatus() else { return .denied }
            return authorizationStatus.genericStatus
        }
    }

    var isAuthorized: Bool {
        switch status {
        case .authorized, .authorizedWhenInUse:
            return true
        case .denied, .notDetermined, .restricted, .unknown:
            return false
        }
    }

    private func fetchNotificationsAuthorizationStatus() -> UNAuthorizationStatus? {
        if self != .notification { return nil }
        // Fix for UNNotificationCenter & @IBDesignable - https://stackoverflow.com/a/55803896/486182
        if ProcessInfo().processName.hasPrefix("IBDesignablesAgent") { return .notDetermined }
        var notificationSettings: UNNotificationSettings?
        let semaphore = DispatchSemaphore(value: 0)

        DispatchQueue.global().async {
            UNUserNotificationCenter.current().getNotificationSettings { setttings in
                notificationSettings = setttings
                semaphore.signal()
            }
        }

        semaphore.wait()
        return notificationSettings?.authorizationStatus
    }

    func updateInitial() {
        switch self {
        case .notification:
            // if the user has already given permission, this allows us to register before the next launch
            // if they haven't, this is still fine; you don't need permission to register for remote ones
            UIApplication.shared.registerForRemoteNotifications()
        case .location, .motion:
            break
        }
    }

    func request(_ completionHandler: @escaping (Bool, PermissionStatus) -> Void) {
        switch self {
        case .location:
            if PermissionsLocationDelegate.shared == nil {
                PermissionsLocationDelegate.shared = PermissionsLocationDelegate()
            }

            PermissionsLocationDelegate.shared!.requestPermission { (status) in
                DispatchQueue.main.async {
                    completionHandler(status == .authorized || status == .authorizedWhenInUse, status)
                    PermissionsLocationDelegate.shared = nil
                }
            }
        case .motion:
            let manager = CMMotionActivityManager()
            let now = Date()

            manager.queryActivityStarting(from: now, to: now, to: .main, withHandler: { (_, error: Error?) -> Void in
                if let error = error as NSError?,
                    error.domain == CMErrorDomain,
                    error.code == CMErrorMotionActivityNotAuthorized.rawValue {
                    completionHandler(false, .denied)
                    return
                }
                completionHandler(true, .authorized)
                return
            })
        case .notification:
            UNUserNotificationCenter.current().requestAuthorization(options: .defaultOptions) { (granted, error) in
                if let error = error {
                    Current.Log.error("Error when requesting notifications permissions: \(error)")
                }
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    let status: PermissionStatus = granted ? .authorized : .denied
                    completionHandler(granted, status)
                }
            }
        }
    }
}

public extension UNAuthorizationOptions {
    static var defaultOptions: UNAuthorizationOptions {
        var opts: UNAuthorizationOptions = [.alert, .badge, .sound, .providesAppNotificationSettings]

        if !Current.isCatalyst {
            // we don't have provisioning for critical alerts in catalyst yet, and asking for permission errors
            opts.insert(.criticalAlert)
        }

        if #available(iOS 13.0, *) {
            opts.insert(.announcement)
        }

        return opts
    }
}

private class PermissionsLocationDelegate: NSObject, CLLocationManagerDelegate {

    static var shared: PermissionsLocationDelegate?

    lazy var locationManager: CLLocationManager = {
        return CLLocationManager()
    }()

    typealias LocationPermissionCompletionBlock = (PermissionStatus) -> Void
    var completionHandler: LocationPermissionCompletionBlock?

    override init() {
        super.init()
    }

    @available(iOS 14, *)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .notDetermined {
            return
        }

        completionHandler?(manager.authorizationStatus.genericStatus)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .notDetermined {
            return
        }

        completionHandler?(status.genericStatus)
    }

    func requestPermission(_ completionHandler: @escaping LocationPermissionCompletionBlock) {
        self.completionHandler = completionHandler

        let status = CLLocationManager.authorizationStatus()

        switch status {
        case .authorizedWhenInUse, .notDetermined:
            locationManager.delegate = self
            locationManager.requestAlwaysAuthorization()
        default:
            completionHandler(status.genericStatus)
        }
    }

    var isAuthorized: Bool {
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        case .denied, .notDetermined, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    deinit {
        locationManager.delegate = nil
    }
}
