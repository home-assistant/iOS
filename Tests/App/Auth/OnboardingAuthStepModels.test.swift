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
        api = HomeAssistantAPI(server: .fake())
        api.connection = connection
        sender = UIViewController()

        step = OnboardingAuthStepModels(api: api, sender: sender)
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
        modelManager.expectedApis = [api]
        let result = step.perform(point: .afterRegister)
        XCTAssertNoThrow(try hang(result))
    }

    func testPerformFailure() {
        modelManager.fetchResult = .init(error: TestError.any)
        modelManager.expectedApis = [api]
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
    var expectedApis: [HomeAssistantAPI] = []

    override func fetch(
        definitions: [FetchDefinition] = FetchDefinition.defaults,
        apis: [HomeAssistantAPI] = Current.apis
    ) -> Promise<Void> {
        XCTAssertEqual(expectedApis.map(\.server), apis.map(\.server))
        return fetchResult
    }
}
