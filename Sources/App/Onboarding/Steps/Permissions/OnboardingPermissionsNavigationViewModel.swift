import CoreLocation
import Foundation
import Shared
import UIKit

final class OnboardingPermissionsNavigationViewModel: NSObject, ObservableObject {
    /// Defines the different steps in the onboarding permissions flow
    enum StepID: String, CaseIterable, Identifiable {
        /// Initial disclaimer step explaining local access functionality
        case disclaimer
        /// Location permission request step for sharing location with Home Assistant
        case location
        /// Local access permission step for secure local connections
        case localAccess
        /// Home network SSID input step for trusted network configuration
        case homeNetwork
        /// Final completion step that triggers onboarding completion
        case completion
        /// Step indicating preferences were updated successfully
        case updatePreferencesSuccess

        var id: String { rawValue }

        /// Default onboarding flow steps
        static var `default`: [StepID] = [.disclaimer, .location, .localAccess, .homeNetwork, .completion]
        /// Flow when user already has remote connection setup, skipping local access disclaimer
        static var remoteConnectionCompatible: [StepID] = [.location, .localAccess, .homeNetwork, .completion]
        /// Flow for updating local access security level preference
        static var updateLocalAccessSecurityLevelPreference: [StepID] = [
            .localAccess,
            .homeNetwork,
            .updatePreferencesSuccess,
        ]
        /// Flow for updating location permission preference
        static var updateLocationPermission: [StepID] = [
            .location,
            .localAccess,
            .homeNetwork,
            .updatePreferencesSuccess,
        ]
    }

    /// Tracks the context in which location permission is being requested
    enum LocationPermissionContext {
        /// Location permission has not been requested yet
        case notRequested
        /// Location permission is being requested to share location data with Home Assistant
        case shareWithHomeAssistant
        /// Location permission is being requested for secure local network connections
        case secureLocalConnection
    }

    // MARK: - Published Properties

    /// Current step index in the onboarding flow (0-based)
    @Published var currentStepIndex: Int = 0

    /// The context in which location permission is being requested
    @Published var locationPermissionContext: LocationPermissionContext = .notRequested

    /// SSID Stored into server settings
    @Published var storedSSIDSuccessfully: Bool = false

    // MARK: - Private Properties

    /// Tracks the previous step index for determining animation direction
    private var lastStepIndex: Int = 0

    private let locationManager = CLLocationManager()
    private let onboardingServer: Server

    // MARK: - Step Management

    /// Returns all available steps in the onboarding flow
    let steps: [StepID]

    /// Determines if the user is advancing forward through the steps (for animation purposes)
    var isAdvancing: Bool {
        currentStepIndex >= lastStepIndex
    }

    /// Returns the current step based on the current step index
    var currentStep: StepID {
        guard currentStepIndex < steps.count else { return .completion }
        return steps[currentStepIndex]
    }

    init(onboardingServer: Server, steps: [StepID]? = nil) {
        self.onboardingServer = onboardingServer

        if let customSteps = steps {
            // Use externally provided steps
            self.steps = customSteps
        } else {
            // Use default logic to determine steps
            var defaultSteps = StepID.default

            // No need to display local access only disclaimer when user already has remote connection setup
            if onboardingServer.info.connection.hasRemoteConnectionSetup {
                defaultSteps = StepID.remoteConnectionCompatible
            }
            self.steps = defaultSteps
        }

        super.init()
    }

    // MARK: - Navigation Methods

    /// Navigates to a specific step in the onboarding flow
    /// - Parameter index: The target step index (0-based)
    /// - Note: Provides haptic feedback for forward navigation and validates bounds
    func navigateToStep(at index: Int) {
        guard index >= 0, index < steps.count else { return }

        // Add haptic feedback for forward navigation
        if index > currentStepIndex {
            Current.impactFeedback.impactOccurred()
        }

        // Update the last step after deciding transition direction
        lastStepIndex = currentStepIndex
        currentStepIndex = index
    }

    /// Navigates to a specific step by its identifier
    func navigateToStep(_ stepId: StepID) {
        if let index = steps.firstIndex(of: stepId) {
            navigateToStep(at: index)
        }
    }

    /// Advances to the next step in the onboarding flow
    /// - Note: Uses navigateToStep internally to handle bounds checking and feedback
    func nextStep() {
        navigateToStep(at: currentStepIndex + 1)
    }

    // MARK: - Step-Specific Actions

    /// Saves the home network SSID to the onboarding server configuration
    /// - Parameter ssid: The network SSID to save for trusted local connections
    /// - Note: This is used in the homeNetwork step to configure secure local access
    func saveHomeNetwork(_ context: HomeNetworkInputView.HomeNetworkInputViewSubmitContext) {
        onboardingServer.update { [weak self] info in
            if let ssid = context.networkName {
                info.connection.internalSSIDs = [ssid]
            }
            if let bssid = context.hardwareAddress {
                info.connection.internalHardwareAddresses = [bssid]
            }
            DispatchQueue.main.async {
                self?.storedSSIDSuccessfully = true
            }
        }
    }

    /// Completes the onboarding process after a brief delay
    /// - Note: Called from the completion step to finalize the onboarding flow
    func completeOnboarding() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Current.onboardingObservation.complete()
        }
    }

    // MARK: - Location Permission Management

    /// Requests location permission specifically for sharing location data with Home Assistant
    /// - Note: Sets context to shareWithHomeAssistant before requesting permission
    func requestLocationPermissionToShareWithHomeAssistant() {
        locationPermissionContext = .shareWithHomeAssistant
        requestLocationPermission()
    }

    /// Requests location permission specifically for secure local network connections
    /// - Note: Sets context to secureLocalConnection before requesting permission
    func requestLocationPermissionForSecureLocalConnection() {
        locationPermissionContext = .secureLocalConnection
        requestLocationPermission()
    }

    /// Configures the server for less secure local connections (when location permission is denied)
    /// - Note: Sets security level to .lessSecure as fallback option
    func setLessSecureLocalConnection() {
        onboardingServer.update { info in
            info.connection.connectionAccessSecurityLevel = .lessSecure
        }
    }

    /// Disables location-related sensors when permission is denied or not wanted
    /// - Note: Affects geocoded location, WiFi BSSID, and SSID sensors
    func disableLocationSensor() {
        onboardingServer.info.setSetting(value: ServerLocationPrivacy.never, for: .locationPrivacy)
    }

    // MARK: - Private Location Methods

    /// Enables location-related sensors when permission is granted
    /// - Note: Affects geocoded location, WiFi BSSID, and SSID sensors
    private func enableLocationSensor() {
        onboardingServer.info.setSetting(value: ServerLocationPrivacy.exact, for: .locationPrivacy)
    }

    /// Handles the actual location permission request based on current authorization status
    /// - Note: Opens settings if denied/restricted, grants immediately if already authorized,
    ///         or requests permission if not determined
    private func requestLocationPermission() {
        switch Current.location.permissionStatus {
        case .denied, .restricted:
            // Open iOS settings for user to manually enable location
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission already granted, apply the context-specific needs
            applyLocationPermissionNeeds()
        default:
            // Permission not determined, request it from the system
            locationManager.delegate = self
            locationManager.requestWhenInUseAuthorization()
        }
    }

    /// Applies the appropriate configuration based on the location permission context
    /// - Note: Enables sensors for Home Assistant sharing or sets security level for local connections
    private func applyLocationPermissionNeeds() {
        if locationPermissionContext == .shareWithHomeAssistant {
            // Enable location sensors for sharing with Home Assistant
            enableLocationSensor()
        }

        if locationPermissionContext == .secureLocalConnection {
            // Configure most secure local connection using location data
            onboardingServer.update { info in
                info.connection.connectionAccessSecurityLevel = .mostSecure
            }
        }

        nextStep()
    }
}

// MARK: - CLLocationManagerDelegate Protocol

extension OnboardingPermissionsNavigationViewModel: CLLocationManagerDelegate {
    /// Handles changes in location authorization status during the onboarding flow
    /// - Parameter manager: The location manager that triggered the authorization change
    /// - Note: This is called when the user responds to location permission requests
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            // Initial state - no action needed yet
            break
        case .restricted:
            // Location services restricted by parental controls or device management
            break
        case .denied:
            // User explicitly denied location access - disable related sensors
            disableLocationSensor()
        case .authorizedAlways:
            // Full location access granted - no additional action needed
            break
        case .authorizedWhenInUse:
            // Limited location access - request always authorization for better functionality
            manager.requestAlwaysAuthorization()
        case .authorized:
            // Legacy authorization status - handled below
            break
        @unknown default:
            // Handle future authorization statuses
            break
        }

        // Only proceed if we have some form of location authorization
        // No need to proceed if permission is .authorizedAlways since the code has run before for .authorizedWhenInUse
        guard manager.authorizationStatus == .authorizedWhenInUse else { return }
        applyLocationPermissionNeeds()
    }
}
