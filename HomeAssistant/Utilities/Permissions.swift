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

@available(iOS 11.0, *)
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
            if #available(iOS 11.0, *) {
                return CMMotionActivityManager.authorizationStatus().genericStatus
            }
            return .denied
        case .notification:
            guard let authorizationStatus = self.fetchNotificationsAuthorizationStatus() else { return .denied }
            return authorizationStatus.genericStatus
        }
    }

    var isAuthorized: Bool {
        return self.status == .authorized
    }

    var isDenied: Bool {
        return self.status != .authorized
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

    func request(_ completionHandler: @escaping (Bool, PermissionStatus) -> Void) {
        switch self {
        case .location:
            PermissionsLocationDelegate().requestPermission { (status) in
                DispatchQueue.main.async {
                    completionHandler(status == .authorized, status)
                }
            }
        case .motion:
            let manager = CMMotionActivityManager()
            let now = Date()

            manager.queryActivityStarting(from: now, to: now, to: .main, withHandler: { (_, error: Error?) -> Void in
                if let error = error as? CMError, error == CMErrorMotionActivityNotAuthorized {
                    completionHandler(false, .denied)
                    return
                }
                completionHandler(true, .authorized)
                return
            })
        case .notification:
            var opts: UNAuthorizationOptions = [.alert, .badge, .sound]
            if #available(iOS 12.0, *) {
                opts.formUnion([.criticalAlert, .providesAppNotificationSettings])
            }
            UNUserNotificationCenter.current().requestAuthorization(options: opts) { (granted, error) in
                if let error = error {
                    Current.Log.error("Error when requesting notifications permissions: \(error)")
                }
                UIApplication.shared.registerForRemoteNotifications()
                DispatchQueue.main.async {
                    let status: PermissionStatus = granted ? .authorized : .denied
                    completionHandler(granted, status)
                }
            }
        }
    }
}

private class PermissionsLocationDelegate: NSObject, CLLocationManagerDelegate {

    lazy var locationManager: CLLocationManager = {
        return CLLocationManager()
    }()

    typealias LocationPermissionCompletionBlock = (PermissionStatus) -> Void
    var completionHandler: LocationPermissionCompletionBlock?

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
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
        return CLLocationManager.authorizationStatus() == .authorizedAlways
    }

    deinit {
        locationManager.delegate = nil
    }
}
