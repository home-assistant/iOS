import HAKit
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class OnboardingAuthStepModelsTests: XCTestCase {
    private var step: OnboardingAuthStepModels!
    private var api: HomeAssistantAPI!
    private var connection: HAMockConnection!
    private var sender: UIViewController!
    private var modelManager: FakeModelManager!

    override func setUp() {
        super.setUp()

        modelManager = FakeModelManager()
        Current.modelManager = modelManager

        connection = HAMockConnection()
        api = HomeAssistantAPI(tokenInfo: .init(
            accessToken: "access_token",
            refreshToken: "refresh_token",
            expiration: .init(timeIntervalSinceNow: 100)
        ))
        sender = UIViewController()

        step = OnboardingAuthStepModels(connection: connection, api: api, sender: sender)
    }

    override func tearDown() {
        super.tearDown()

        Current.modelManager = .init()
    }

    func testSupportedPoints() {
        XCTAssertTrue(OnboardingAuthStepModels.supportedPoints.contains(.afterRegister))
    }

    func testPerformSuccess() {
        modelManager.fetchResult = .value(())
        let result = step.perform(point: .afterRegister)
        XCTAssertNoThrow(try hang(result))
    }

    func testPerformFailure() {
        modelManager.fetchResult = .init(error: TestError.any)
        let result = step.perform(point: .afterRegister)
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .any)
        }
    }
}

private enum TestError: Error {
    case any
}

private class FakeModelManager: ModelManager {
    var fetchResult: Promise<Void> = .value(())

    override func fetch(
        definitions: [FetchDefinition] = FetchDefinition.defaults,
        on queue: DispatchQueue = .global(qos: .utility)
    ) -> Promise<Void> {
        fetchResult
    }
}
