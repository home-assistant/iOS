@testable import HomeAssistant
import Shared
import Testing

@Suite("OnboardingPrivacyViewModel Tests")
struct OnboardingPrivacyViewModelTests {
    @MainActor @Test("Starts on the values a server falls back to when nobody picks any")
    func startsOnTheSettingDefaults() async throws {
        let viewModel = OnboardingPrivacyViewModel()

        #expect(viewModel.locationPrivacy == ServerLocationPrivacy.defaultSettingValue)
        #expect(viewModel.sensorPrivacy == ServerSensorPrivacy.defaultSettingValue)
        #expect(viewModel.locationSelection.wrappedValue == ServerLocationPrivacy.defaultSettingValue.rawValue)
        #expect(viewModel.sensorSelection.wrappedValue == ServerSensorPrivacy.defaultSettingValue.rawValue)
    }

    @MainActor @Test("Offers every location and sensor privacy level")
    func offersEveryPrivacyLevel() async throws {
        let viewModel = OnboardingPrivacyViewModel()

        #expect(viewModel.locationOptions.map(\.value) == ServerLocationPrivacy.allCases.map(\.rawValue))
        #expect(viewModel.sensorOptions.map(\.value) == ServerSensorPrivacy.allCases.map(\.rawValue))
        #expect(viewModel.locationOptions.allSatisfy { $0.subtitle?.isEmpty == false })
        #expect(viewModel.sensorOptions.allSatisfy { $0.subtitle?.isEmpty == false })
        #expect(viewModel.locationOptions.allSatisfy { $0.accessibilityIdentifier?.isEmpty == false })
        #expect(viewModel.sensorOptions.allSatisfy { $0.accessibilityIdentifier?.isEmpty == false })
    }

    @MainActor @Test("Selecting an option stores its privacy level")
    func selectingAnOptionStoresItsPrivacyLevel() async throws {
        let viewModel = OnboardingPrivacyViewModel()

        viewModel.locationSelection.wrappedValue = ServerLocationPrivacy.zoneOnly.rawValue
        viewModel.sensorSelection.wrappedValue = ServerSensorPrivacy.none.rawValue

        #expect(viewModel.locationPrivacy == .zoneOnly)
        #expect(viewModel.sensorPrivacy == ServerSensorPrivacy.none)
    }

    @MainActor @Test("A value that is not an option leaves the choice alone")
    func unknownValueKeepsTheCurrentChoice() async throws {
        let viewModel = OnboardingPrivacyViewModel(locationPrivacy: .never, sensorPrivacy: .none)

        viewModel.locationSelection.wrappedValue = "not-a-privacy-level"
        viewModel.locationSelection.wrappedValue = nil
        viewModel.sensorSelection.wrappedValue = "not-a-privacy-level"
        viewModel.sensorSelection.wrappedValue = nil

        #expect(viewModel.locationPrivacy == .never)
        #expect(viewModel.sensorPrivacy == ServerSensorPrivacy.none)
    }

    @MainActor @Test("Submitting hands over the choices that are selected")
    func submittingHandsOverTheSelectedChoices() async throws {
        var submitted: (location: ServerLocationPrivacy, sensors: ServerSensorPrivacy)?
        let viewModel = OnboardingPrivacyViewModel { location, sensors in
            submitted = (location, sensors)
        }

        viewModel.locationSelection.wrappedValue = ServerLocationPrivacy.zoneOnly.rawValue
        viewModel.submit()

        #expect(submitted?.location == .zoneOnly)
        #expect(submitted?.sensors == ServerSensorPrivacy.defaultSettingValue)
    }
}
