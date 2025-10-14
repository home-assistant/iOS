import Testing
import Testing
import CoreLocation
import Foundation
import Shared
@testable import HomeAssistant

// MARK: - Test Fixtures
@Suite("OnboardingPermissionsNavigationViewModel Tests")
struct OnboardingPermissionsNavigationViewModelTests {
    
    // MARK: - Initialization Tests
    
    @Test("Initialization with default steps")
    func initializationWithDefaultSteps() async throws {
        ServerFixture.reset()
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        
        #expect(viewModel.steps == OnboardingPermissionsNavigationViewModel.StepID.default)
        #expect(viewModel.currentStepIndex == 0)
        #expect(viewModel.locationPermissionContext == .notRequested)
        #expect(viewModel.currentStep == .disclaimer)
    }
    
    @Test("Initialization with remote connection setup")
    func initializationWithRemoteConnectionSetup() async throws {
        let server = ServerFixture.withRemoteConnection
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        
        #expect(viewModel.steps == OnboardingPermissionsNavigationViewModel.StepID.remoteConnectionCompatible)
        #expect(viewModel.currentStep == .location)
    }
    
    @Test("Initialization with custom steps")
    func initializationWithCustomSteps() async throws {
        let server = ServerFixture.standard
        let customSteps: [OnboardingPermissionsNavigationViewModel.StepID] = [.location, .completion]
        let viewModel = OnboardingPermissionsNavigationViewModel(
            onboardingServer: server,
            steps: customSteps
        )
        
        #expect(viewModel.steps == customSteps)
        #expect(viewModel.currentStep == .location)
    }
    
    // MARK: - Step Management Tests
    
    @Test("Current step returns correct step")
    func currentStepReturnsCorrectStep() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        
        #expect(viewModel.currentStep == .disclaimer)
        
        viewModel.navigateToStep(at: 1)
        #expect(viewModel.currentStep == .location)
        
        viewModel.navigateToStep(at: 2)
        #expect(viewModel.currentStep == .localAccess)
    }
    
    @Test("Current step handles out of bounds index")
    func currentStepHandlesOutOfBoundsIndex() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        
        // Test the computed property behavior when currentStepIndex is out of bounds
        // We need to manually set currentStepIndex since navigateToStep has bounds checking
        viewModel.currentStepIndex = 999 // Directly set out of bounds index
        #expect(viewModel.currentStep == .completion)
        
        // Also test that navigateToStep prevents out of bounds navigation
        let originalIndex = 0
        viewModel.currentStepIndex = originalIndex
        viewModel.navigateToStep(at: 999) // Should not change currentStepIndex
        #expect(viewModel.currentStepIndex == originalIndex)
    }
    
    @Test("Is advancing detection")
    func isAdvancingDetection() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        
        // Initially advancing (0 >= 0)
        #expect(viewModel.isAdvancing == true)
        
        // Move forward
        viewModel.navigateToStep(at: 2)
        #expect(viewModel.isAdvancing == true)
        
        // Move backward
        viewModel.navigateToStep(at: 1)
        #expect(viewModel.isAdvancing == false)
    }
    
    // MARK: - Navigation Tests
    
    @Test("Navigate to step by index")
    func navigateToStepByIndex() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        
        viewModel.navigateToStep(at: 2)
        #expect(viewModel.currentStepIndex == 2)
        #expect(viewModel.currentStep == .localAccess)
    }
    
    @Test("Navigate to step by index with bounds checking")
    func navigateToStepByIndexWithBoundsChecking() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        let initialIndex = viewModel.currentStepIndex
        
        // Test negative index
        viewModel.navigateToStep(at: -1)
        #expect(viewModel.currentStepIndex == initialIndex) // Should not change
        
        // Test index too high
        viewModel.navigateToStep(at: 999)
        #expect(viewModel.currentStepIndex == initialIndex) // Should not change
    }
    
    @Test("Navigate to step by identifier")
    func navigateToStepByIdentifier() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        
        viewModel.navigateToStep(.location)
        #expect(viewModel.currentStep == .location)
        #expect(viewModel.currentStepIndex == 1)
        
        viewModel.navigateToStep(.completion)
        #expect(viewModel.currentStep == .completion)
        #expect(viewModel.currentStepIndex == 4)
    }
    
    @Test("Navigate to step by non-existent identifier")
    func navigateToStepByNonExistentIdentifier() async throws {
        let server = ServerFixture.standard
        let customSteps: [OnboardingPermissionsNavigationViewModel.StepID] = [.location, .completion]
        let viewModel = OnboardingPermissionsNavigationViewModel(
            onboardingServer: server,
            steps: customSteps
        )
        let initialIndex = viewModel.currentStepIndex
        
        viewModel.navigateToStep(.disclaimer) // Not in custom steps
        #expect(viewModel.currentStepIndex == initialIndex) // Should not change
    }
    
    @Test("Next step navigation")
    func nextStepNavigation() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        
        #expect(viewModel.currentStepIndex == 0)
        
        viewModel.nextStep()
        #expect(viewModel.currentStepIndex == 1)
        #expect(viewModel.currentStep == .location)
        
        viewModel.nextStep()
        #expect(viewModel.currentStepIndex == 2)
        #expect(viewModel.currentStep == .localAccess)
    }
    
    // MARK: - Network SSID Tests
    
    @Test("Save network SSID")
    func saveNetworkSSID() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        
        let testSSID = "TestNetwork"
        viewModel.saveNetworkSSID(testSSID)
        
        #expect(server.info.connection.internalSSIDs == [testSSID])
    }
    
    // MARK: - Location Permission Context Tests
    
    @Test("Request location permission for Home Assistant sharing")
    func requestLocationPermissionForHomeAssistantSharing() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        
        viewModel.requestLocationPermissionToShareWithHomeAssistant()
        #expect(viewModel.locationPermissionContext == .shareWithHomeAssistant)
    }
    
    @Test("Request location permission for secure local connection")
    func requestLocationPermissionForSecureLocalConnection() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        
        viewModel.requestLocationPermissionForSecureLocalConnection()
        #expect(viewModel.locationPermissionContext == .secureLocalConnection)
    }
    
    @Test("Set less secure local connection")
    func setLessSecureLocalConnection() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        
        viewModel.setLessSecureLocalConnection()
        #expect(server.info.connection.localAccessSecurityLevel == .lessSecure)
    }
    
    @Test("Disable location sensor")
    func disableLocationSensor() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        
        viewModel.disableLocationSensor()
        
        let locationPrivacy = server.info.setting(for: .locationPrivacy)
        #expect(locationPrivacy == .never)
    }
    
    // MARK: - StepID Tests
    
    @Test("StepID identifiable conformance")
    func stepIDIdentifiableConformance() async throws {
        let step = OnboardingPermissionsNavigationViewModel.StepID.disclaimer
        #expect(step.id == "disclaimer")
        #expect(step.id == step.rawValue)
    }
    
    @Test("StepID case iteration")
    func stepIDCaseIteration() async throws {
        let allCases = OnboardingPermissionsNavigationViewModel.StepID.allCases
        #expect(allCases.contains(.disclaimer))
        #expect(allCases.contains(.location))
        #expect(allCases.contains(.localAccess))
        #expect(allCases.contains(.homeNetwork))
        #expect(allCases.contains(.completion))
        #expect(allCases.contains(.updatePreferencesSuccess))
    }
    
    @Test("StepID static flow configurations")
    func stepIDStaticFlowConfigurations() async throws {
        let defaultFlow = OnboardingPermissionsNavigationViewModel.StepID.default
        #expect(defaultFlow == [.disclaimer, .location, .localAccess, .homeNetwork, .completion])
        
        let remoteCompatibleFlow = OnboardingPermissionsNavigationViewModel.StepID.remoteConnectionCompatible
        #expect(remoteCompatibleFlow == [.location, .localAccess, .homeNetwork, .completion])
        
        let updateLocalAccessFlow = OnboardingPermissionsNavigationViewModel.StepID.updateLocalAccessSecurityLevelPreference
        #expect(updateLocalAccessFlow == [.localAccess, .homeNetwork, .updatePreferencesSuccess])
        
        let updateLocationFlow = OnboardingPermissionsNavigationViewModel.StepID.updateLocationPermission
        #expect(updateLocationFlow == [.location, .localAccess, .homeNetwork, .updatePreferencesSuccess])
    }
    
    // MARK: - LocationPermissionContext Tests
    
    @Test("LocationPermissionContext enum cases")
    func locationPermissionContextEnumCases() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        
        // Test initial state
        #expect(viewModel.locationPermissionContext == .notRequested)
        
        // Test setting different contexts
        viewModel.locationPermissionContext = .shareWithHomeAssistant
        #expect(viewModel.locationPermissionContext == .shareWithHomeAssistant)
        
        viewModel.locationPermissionContext = .secureLocalConnection
        #expect(viewModel.locationPermissionContext == .secureLocalConnection)
        
        viewModel.locationPermissionContext = .notRequested
        #expect(viewModel.locationPermissionContext == .notRequested)
    }
}

// MARK: - Location Manager Delegate Tests

@Suite("OnboardingPermissionsNavigationViewModel Location Delegate Tests")
struct OnboardingPermissionsNavigationViewModelLocationDelegateTests {
    
    init() {
        // Reset fixtures before each test suite
        ServerFixture.reset()
    }
    
    @Test("Location manager authorization change - when in use granted")
    func locationManagerAuthorizationChangeWhenInUse() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        viewModel.locationPermissionContext = .shareWithHomeAssistant
        
        // Create a mock location manager
        let mockLocationManager = MockCLLocationManager()
        mockLocationManager.authorizationStatus = .authorizedWhenInUse
        
        // Simulate authorization change
        viewModel.locationManagerDidChangeAuthorization(mockLocationManager)
        
        // Should advance to next step
        #expect(viewModel.currentStepIndex == 1)
    }
    
    @Test("Location manager authorization change - denied")
    func locationManagerAuthorizationChangeDenied() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        
        let mockLocationManager = MockCLLocationManager()
        mockLocationManager.authorizationStatus = .denied
        
        viewModel.locationManagerDidChangeAuthorization(mockLocationManager)
        
        // Should disable location sensor
        let locationPrivacy = server.info.setting(for: .locationPrivacy)
        #expect(locationPrivacy == .never)
    }
    
    @Test("Location manager authorization change - not determined")
    func locationManagerAuthorizationChangeNotDetermined() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        let initialStepIndex = viewModel.currentStepIndex
        
        let mockLocationManager = MockCLLocationManager()
        mockLocationManager.authorizationStatus = .notDetermined
        
        viewModel.locationManagerDidChangeAuthorization(mockLocationManager)
        
        // Should not advance step
        #expect(viewModel.currentStepIndex == initialStepIndex)
    }
}

// MARK: - Mock Classes

/// Mock CLLocationManager for testing
class MockCLLocationManager: CLLocationManager {
    private var _authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override var authorizationStatus: CLAuthorizationStatus {
        get { _authorizationStatus }
        set { _authorizationStatus = newValue }
    }
}
