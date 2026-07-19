import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class OnboardingAuthStepSensorsTests: XCTestCase {
    private var step: OnboardingAuthStepSensors!
    private var api: FakeHomeAssistantAPI!
    private var connection: HAMockConnection!
    private var presenter: OnboardingAuthPresenter!

    override func setUp() {
        super.setUp()

        connection = HAMockConnection()
        api = FakeHomeAssistantAPI(server: .fake())
        api.connection = connection
        presenter = OnboardingAuthPresenter()

        step = OnboardingAuthStepSensors(api: api, presenter: presenter)
    }

    func testSupportedPoints() {
        XCTAssertTrue(OnboardingAuthStepSensors.supportedPoints.contains(.afterRegister))
    }

    func testPerformSuccess() {
        let result = step.perform(point: .afterRegister)

        XCTAssertFalse(result.isResolved)
        api.registerSensorsResolver?.fulfill(())
        XCTAssertNoThrow(try hang(result))
    }

    func testPerformFailure() {
        let result = step.perform(point: .afterRegister)

        XCTAssertFalse(result.isResolved)
        api.registerSensorsResolver?.reject(TestError.any)
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .any)
        }
    }
}

private enum TestError: Error {
    case any
}

private class FakeHomeAssistantAPI: HomeAssistantAPI {
    var registerSensorsResolver: Resolver<Void>?
    override func registerSensors() -> Promise<Void> {
        let (promise, resolver) = Promise<Void>.pending()
        registerSensorsResolver = resolver
        return promise
    }
}
