@testable import HomeAssistant
import Shared
import Testing

@Suite("OnboardingPrivacyViewModel Tests")
struct OnboardingPrivacyViewModelTests {
    @MainActor @Test("Starts with nothing selected and cannot be submitted")
    func startsWithNothingSelected() async throws {
        let viewModel = OnboardingPrivacyViewModel()

        #expect(viewModel.locationPrivacy == nil)
        #expect(viewModel.sensorPrivacy == nil)
        #expect(viewModel.locationSelection.wrappedValue == nil)
        #expect(viewModel.sensorSelection.wrappedValue == nil)
        #expect(viewModel.canSubmit == false)
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
        #expect(viewModel.locationSelection.wrappedValue == ServerLocationPrivacy.zoneOnly.rawValue)
        #expect(viewModel.sensorSelection.wrappedValue == ServerSensorPrivacy.none.rawValue)
    }

    @MainActor @Test("A value that is not an option leaves the choice alone")
    func unknownValueKeepsTheCurrentChoice() async throws {
        let viewModel = OnboardingPrivacyViewModel(locationPrivacy: .never, sensorPrivacy: ServerSensorPrivacy.none)

        viewModel.locationSelection.wrappedValue = "not-a-privacy-level"
        viewModel.locationSelection.wrappedValue = nil
        viewModel.sensorSelection.wrappedValue = "not-a-privacy-level"
        viewModel.sensorSelection.wrappedValue = nil

        #expect(viewModel.locationPrivacy == .never)
        #expect(viewModel.sensorPrivacy == ServerSensorPrivacy.none)
    }

    @MainActor @Test("Both questions have to be answered before the step can be left")
    func bothQuestionsHaveToBeAnswered() async throws {
        var submitted: (location: ServerLocationPrivacy, sensors: ServerSensorPrivacy)?
        let viewModel = OnboardingPrivacyViewModel { location, sensors in
            submitted = (location, sensors)
        }

        viewModel.locationSelection.wrappedValue = ServerLocationPrivacy.zoneOnly.rawValue
        #expect(viewModel.canSubmit == false)
        viewModel.submit()
        #expect(submitted == nil)

        viewModel.sensorSelection.wrappedValue = ServerSensorPrivacy.all.rawValue
        #expect(viewModel.canSubmit)
        viewModel.submit()

        #expect(submitted?.location == .zoneOnly)
        #expect(submitted?.sensors == .all)
    }
}
