import CoreLocation
import Foundation

/**
 A comprehensive location management system that provides a clean abstraction over Core Location
 with notification-based updates and protocol-oriented architecture for testability.

 ## Overview

 The LocationManager provides:
 - Permission state management and monitoring
 - Request methods for different authorization levels
 - Automatic notification broadcasting when permissions change
 - Protocol-based design for dependency injection and testing

 ## Usage

 ```swift
 let locationManager = LocationManager()

 // Listen for permission changes
 NotificationCenter.default.addObserver(
     forName: .locationPermissionDidChange,
     object: nil,
     queue: .main
 ) { notification in
     if let userInfo = notification.userInfo,
        let state = userInfo["permissionState"] as? LocationPermissionState {
         // Handle permission change
     }
 }

 // Request permissions
 locationManager.requestLocationPermission()
 locationManager.requestAlwaysLocationPermission()
 ```
 */

// MARK: - Notification Names

public extension Notification.Name {
    /// Posted when location permission state changes
    ///
    /// The notification's `userInfo` dictionary contains:
    /// - `"permissionState"`: The new `LocationPermissionState` value
    static let locationPermissionDidChange = Notification.Name("locationPermissionDidChange")
}

// MARK: - Location Permission State

/**
 Represents the current state of location permissions for the application.

 This enum provides a Swift-native wrapper around `CLAuthorizationStatus` with
 more descriptive cases and easier pattern matching.
 */
public enum LocationPermissionState {
    /// The user has not yet been asked for location permission
    case notDetermined

    /// The user has explicitly denied location permission
    case denied

    /// Location services are restricted, typically due to parental controls
    case restricted

    /// Location permission is granted only when the app is in use
    case authorizedWhenInUse

    /// Location permission is granted always (background and foreground)
    case authorizedAlways

    /**
     Creates a LocationPermissionState from a CLAuthorizationStatus.

     - Parameter authorizationStatus: The Core Location authorization status
     */
    init(from authorizationStatus: CLAuthorizationStatus) {
        switch authorizationStatus {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        case .authorizedWhenInUse:
            self = .authorizedWhenInUse
        case .authorizedAlways:
            self = .authorizedAlways
        @unknown default:
            self = .notDetermined
        }
    }

    public init(userInfo: [AnyHashable: Any]) {
        if let permissionState = userInfo["permissionState"] as? LocationPermissionState {
            self = permissionState
        } else {
            fatalError(
                "Failed to initialize LocationPermissionState: userInfo dictionary must contain a \"permissionState\" key with a LocationPermissionState value"
            )
        }
    }
}

// MARK: - Protocol

/**
 Protocol defining the interface for location management operations.

 This protocol abstracts location permission management to enable:
 - Dependency injection in production code
 - Easy mocking for unit tests
 - Swappable implementations for different use cases

 ## Required Implementation

 Conforming types must provide:
 - Current permission state monitoring
 - Permission request methods
 - Location services availability checking
 */
public protocol LocationManagerProtocol: AnyObject {
    /// The current location permission state for the application
    var currentPermissionState: LocationPermissionState { get }

    /// The level of location accuracy the user has authorized for the application
    ///
    /// This property indicates whether the user has granted full or reduced accuracy
    /// location access. When reduced accuracy is in effect, location data is less precise.
    ///
    /// Possible values:
    /// - `.fullAccuracy`: The user has granted full location accuracy
    /// - `.reducedAccuracy`: The user has enabled approximate location mode
    ///
    /// - Note: Users can control accuracy authorization in Settings, independent of
    ///   whether they've granted location permission itself.
    var accuracyAuthorization: CLAccuracyAuthorization { get }

    /// Whether location services are enabled on this device
    ///
    /// - Returns: `true` if location services are enabled system-wide, `false` otherwise
    var isLocationServicesEnabled: Bool { get }

    /// Requests basic location permission (when in use only)
    ///
    /// This method requests permission to access location only when the app is active.
    /// If permission has already been granted or denied, this method has no effect.
    func requestLocationPermission()
}

// MARK: - Implementation

/**
 Concrete implementation of LocationManagerProtocol using Core Location.

 This class provides a complete location management solution with:
 - Automatic permission state monitoring via CLLocationManagerDelegate
 - Notification broadcasting when permissions change
 - Intelligent permission request handling based on current state
 - Thread-safe notification posting

 ## Thread Safety

 LocationManager is designed to be used from the main thread, as required by Core Location.
 All delegate methods and notifications are handled on the main thread.

 ## Notification Broadcasting

 When location permissions change, this class automatically posts
 `Notification.Name.locationPermissionDidChange` notifications with the new state
 included in the userInfo dictionary.
 */
final class LocationManager: NSObject, LocationManagerProtocol {
    // MARK: - Properties

    /// The underlying Core Location manager
    private let coreLocationManager = CLLocationManager()

    /// Notification center for broadcasting permission changes
    private let notificationCenter: NotificationCenter

    // MARK: - Public Properties

    /// The current location permission state
    ///
    /// This property dynamically queries the Core Location manager for the current
    /// authorization status and converts it to our custom enum.
    var currentPermissionState: LocationPermissionState {
        LocationPermissionState(from: coreLocationManager.authorizationStatus)
    }

    /// The level of location accuracy authorized by the user
    ///
    /// Returns the current accuracy authorization level, which determines the precision
    /// of location data provided to the app. This is independent of whether location
    /// permission itself has been granted.
    ///
    /// - Returns: `.fullAccuracy` if the user has granted precise location access,
    ///   or `.reducedAccuracy` if approximate location mode is enabled
    var accuracyAuthorization: CLAccuracyAuthorization {
        coreLocationManager.accuracyAuthorization
    }

    /// Whether location services are enabled system-wide
    ///
    /// This checks if location services are enabled at the device level.
    /// Even if your app has permission, location won't work if this returns false.
    var isLocationServicesEnabled: Bool {
        CLLocationManager.locationServicesEnabled()
    }

    // MARK: - Initialization

    /**
     Creates a new LocationManager instance.

     - Parameter notificationCenter: The notification center to use for broadcasting
       permission changes. Defaults to `NotificationCenter.default`.
     */
    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        super.init()
        setupLocationManager()
    }

    // MARK: - Private Methods

    /**
     Configures the Core Location manager with appropriate settings.

     Sets up:
     - Delegate assignment
     - Desired accuracy (best available)
     */
    private func setupLocationManager() {
        coreLocationManager.delegate = self
        coreLocationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    /**
     Posts a notification when location permission state changes.

     The notification includes the current permission state in its userInfo dictionary
     under the key "permissionState".
     */
    private func postPermissionChangeNotification() {
        let userInfo = ["permissionState": currentPermissionState]
        notificationCenter.post(
            name: .locationPermissionDidChange,
            object: self,
            userInfo: userInfo
        )
    }

    // MARK: - Public Methods

    /**
     Requests basic location permission (when in use only).

     This method handles the permission request intelligently:
     - If location services are disabled system-wide, the request is ignored
     - If permission is not determined, it requests "when in use" authorization
     - If permission is already granted or denied, no action is taken

     ## Permission Flow

     1. Checks if location services are enabled
     2. Evaluates current authorization status
     3. Requests appropriate permission if needed

     - Note: Permission changes are automatically broadcast via NotificationCenter
     */
    func requestLocationPermission() {
        switch coreLocationManager.authorizationStatus {
        case .notDetermined:
            coreLocationManager.requestWhenInUseAuthorization()
        case .denied, .restricted, .authorizedWhenInUse, .authorizedAlways:
            postPermissionChangeNotification()
        @unknown default:
            coreLocationManager.requestWhenInUseAuthorization()
        }
    }
}

// MARK: - CLLocationManagerDelegate

/**
 Core Location delegate implementation.

 This extension handles Core Location callbacks and translates them into
 our notification-based system for cleaner separation of concerns.
 */
extension LocationManager: CLLocationManagerDelegate {
    /**
     Called when the location authorization status changes.

     This method automatically broadcasts a notification with the new permission state,
     allowing other parts of the app to respond to permission changes without tight coupling.

     - Parameter manager: The location manager whose authorization status changed
     */
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        postPermissionChangeNotification()

        if manager.authorizationStatus == .authorizedWhenInUse {
            // If we just got when-in-use authorization, we can now request always authorization
            manager.requestAlwaysAuthorization()
        }
    }

    /**
     Called when the location manager encounters an error.

     Currently logs errors for debugging purposes. In production, you might want to
     handle specific error types or notify the user appropriately.

     - Parameters:
       - manager: The location manager that encountered the error
       - error: The error that occurred
     */
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Handle location errors if needed
        Current.Log.error("Location manager failed with error: \(error.localizedDescription)")
    }
}
