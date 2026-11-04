import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class OnboardingAuthStepNotifyTests: XCTestCase {
    private var step: OnboardingAuthStepNotify!
    private var api: HomeAssistantAPI!
    private var connection: HAMockConnection!
    private var presenter: OnboardingAuthPresenter!

    override func setUp() {
        super.setUp()

        // kill off any existing observers for this test run
        Current.onboardingObservation = .init()

        connection = HAMockConnection()
        api = HomeAssistantAPI(server: .fake())
        api.connection = connection
        presenter = OnboardingAuthPresenter()

        step = OnboardingAuthStepNotify(api: api, presenter: presenter)
    }

    override func tearDown() {
        // XCTest keeps this test case alive for the whole run, and an API left alive stays registered
        // with the app's sensor container, which every later sensor signal fans out to. A request the
        // test never answers would keep it alive through the step's promise chain.
        connection?.pendingRequests.removeAll()
        connection?.pendingSubscriptions.removeAll()
        step = nil
        api = nil
        connection = nil
        presenter = nil
        super.tearDown()
    }

    func testSupportedPoints() {
        XCTAssertTrue(OnboardingAuthStepNotify.supportedPoints.contains(.complete))
    }

    func testPerform() {
        let notificationExpectation = XCTNSNotificationExpectation(
            name: HomeAssistantAPI.didConnectNotification,
            object: nil
        )
        let observationExpectation = expectation(description: "observation")

        let observer = FakeOnboardingStateObserver(expectation: observationExpectation)
        Current.onboardingObservation.register(observer: observer)

        let result = step.perform(point: .complete)
        XCTAssertNoThrow(try hang(result))
        wait(for: [
            notificationExpectation,
            observationExpectation,
        ], timeout: 10.0)

        withExtendedLifetime(observer) {
            //
        }
    }
}

private enum TestError: Error {
    case any
}

private class FakeOnboardingStateObserver: OnboardingStateObserver {
    let expectation: XCTestExpectation
    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onboardingStateDidChange(to state: OnboardingState) {
        if case .didConnect = state {
            expectation.fulfill()
        }
    }
}

private class FakeModelManager: LegacyModelManager {
    var fetchResult: Promise<Void> = .value(())

    override func fetch(
        definitions: [FetchDefinition] = FetchDefinition.defaults,
        apis: [HomeAssistantAPI] = Current.apis
    ) -> Promise<Void> {
        fetchResult
    }
}
