import Foundation
import HAKit
@testable import HomeAssistant
import PromiseKit
@testable import Shared
@testable import Tests_Shared
import XCTest

class OnboardingAuthTests: XCTestCase {
    private var auth: OnboardingAuth!
    private var instance: DiscoveredHomeAssistant!

    override func setUp() {
        super.setUp()

        auth = OnboardingAuth()

        var instance = DiscoveredHomeAssistant(manualURL: URL(string: "https://external.homeassistant:8123")!)
        instance.internalURL = URL(string: "https://internal.homeassistant:8123")!
        self.instance = instance

        Current.isTestingOnboarding = true

        Current.settingsStore.tokenInfo = nil
        Current.settingsStore.connectionInfo = nil
    }

    override func tearDown() {
        super.tearDown()

        Current.isTestingOnboarding = false
    }

    func testPlainSetup() {
        // ObjectIdentifier makes contains easier
        let pre = auth.preSteps.map(ObjectIdentifier.init)
        let post = auth.postSteps.map(ObjectIdentifier.init)

        // normally it is bad to tautologically test that some lines exist in the non-test code
        // however, auth is important enough that removing a step should be _very_ intentional
        XCTAssertTrue(auth.login is OnboardingAuthLoginImpl)
        XCTAssertTrue(auth.tokenExchange is OnboardingAuthTokenExchangeImpl)

        XCTAssertTrue(pre.contains(.init(OnboardingAuthStepConnectivity.self)))

        XCTAssertTrue(post.contains(.init(OnboardingAuthStepDuplicate.self)))
        XCTAssertTrue(post.contains(.init(OnboardingAuthStepConfig.self)))
        XCTAssertTrue(post.contains(.init(OnboardingAuthStepSensors.self)))
        XCTAssertTrue(post.contains(.init(OnboardingAuthStepModels.self)))
        XCTAssertTrue(post.contains(.init(OnboardingAuthStepRegister.self)))
        XCTAssertTrue(post.contains(.init(OnboardingAuthStepNotify.self)))
    }

    func testBeforeAuthFails() throws {
        let result = auth(preBeforeAuth: [.value(()), .init(error: TestError.specific)])
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .specific)
        }

        XCTAssertNil(Current.settingsStore.tokenInfo)
        XCTAssertNil(Current.settingsStore.connectionInfo)
    }

    func testLoginFails() throws {
        let result = auth(loginResult: .init(error: TestError.specific))
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .specific)
        }

        XCTAssertNil(Current.settingsStore.tokenInfo)
        XCTAssertNil(Current.settingsStore.connectionInfo)
    }

    func testTokenFails() throws {
        let result = auth(tokenResult: .init(error: TestError.specific))
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .specific)
        }

        XCTAssertNil(Current.settingsStore.tokenInfo)
        XCTAssertNil(Current.settingsStore.connectionInfo)
    }

    func testBeforeRegisterFails() throws {
        let result = auth(postBeforeRegister: [.value(()), .init(error: TestError.specific)])
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .specific)
        }

        XCTAssertNil(Current.settingsStore.tokenInfo)
        XCTAssertNil(Current.settingsStore.connectionInfo)
    }

    func testRegisterFails() throws {
        let result = auth(postRegister: [.value(()), .init(error: TestError.specific)])
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .specific)
        }

        XCTAssertNil(Current.settingsStore.tokenInfo)
        XCTAssertNil(Current.settingsStore.connectionInfo)
    }

    func testAfterRegisterFails() throws {
        let result = auth(postAfterRegister: [.value(()), .init(error: TestError.specific)])
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .specific)
        }

        XCTAssertNil(Current.settingsStore.tokenInfo)
        XCTAssertNil(Current.settingsStore.connectionInfo)
    }

    func testCompleteFails() throws {
        let result = auth(postComplete: [.value(()), .init(error: TestError.specific)])
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .specific)
        }

        XCTAssertNil(Current.settingsStore.tokenInfo)
        XCTAssertNil(Current.settingsStore.connectionInfo)
    }

    func testCancelledLogin() throws {
        let result = auth(loginResult: .init(error: TestError.cancelled))
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .cancelled)
        }

        XCTAssertNil(Current.settingsStore.tokenInfo)
        XCTAssertNil(Current.settingsStore.connectionInfo)
    }

    func testCancelledBefore() throws {
        let result = auth(postBeforeRegister: [.value(()), .init(error: TestError.cancelled)])
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .cancelled)
        }

        XCTAssertNil(Current.settingsStore.tokenInfo)
        XCTAssertNil(Current.settingsStore.connectionInfo)
    }

    func testSuccessfulWithInternalAndExternal() throws {
        let result = auth()
        XCTAssertNoThrow(try hang(result))
        // test api state
        // add tests above to test negated api state

        let tokenInfo = try XCTUnwrap(Current.settingsStore.tokenInfo)
        XCTAssertEqual(tokenInfo.accessToken, "access_token1")
        XCTAssertEqual(tokenInfo.refreshToken, "refresh_token1")

        let connectionInfo = try XCTUnwrap(Current.settingsStore.connectionInfo)
        XCTAssertEqual(connectionInfo.internalURL, instance.internalURL)
        XCTAssertEqual(connectionInfo.externalURL, instance.externalURL)
        XCTAssertEqual(connectionInfo.overrideActiveURLType, .internal)
    }

    func testSuccessfulWithOnlyExternal() throws {
        instance.internalURL = nil

        let result = auth()
        XCTAssertNoThrow(try hang(result))
        // test api state
        // add tests above to test negated api state

        let tokenInfo = try XCTUnwrap(Current.settingsStore.tokenInfo)
        XCTAssertEqual(tokenInfo.accessToken, "access_token1")
        XCTAssertEqual(tokenInfo.refreshToken, "refresh_token1")

        let connectionInfo = try XCTUnwrap(Current.settingsStore.connectionInfo)
        XCTAssertNil(connectionInfo.internalURL)
        XCTAssertEqual(connectionInfo.externalURL, instance.externalURL)
        XCTAssertNil(connectionInfo.overrideActiveURLType)
    }

    func testOrderPostCommands() throws {
        let postBefore1 = Promise<Void>.pending()
        let postRegister1 = Promise<Void>.pending()
        let postAfter1 = Promise<Void>.pending()
        let postComplete1 = Promise<Void>.pending()

        let result = auth(
            postBeforeRegister: [postBefore1.promise],
            postRegister: [postRegister1.promise],
            postAfterRegister: [postAfter1.promise],
            postComplete: [postComplete1.promise]
        )

        let expectation1 = expectation(description: "1")
        try XCTUnwrap(FakeOnboardingAuthPostStepBeforeRegister1.wasInvokedPromise).done {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 10.0)

        XCTAssertTrue(FakeOnboardingAuthPostStepBeforeRegister1.wasInvoked)
        XCTAssertFalse(FakeOnboardingAuthPostStepRegister1.wasInvoked)
        XCTAssertFalse(FakeOnboardingAuthPostStepAfterRegister1.wasInvoked)
        XCTAssertFalse(FakeOnboardingAuthPostStepComplete1.wasInvoked)

        postBefore1.resolver.fulfill(())

        let expectation2 = expectation(description: "2")
        try XCTUnwrap(FakeOnboardingAuthPostStepRegister1.wasInvokedPromise).done {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 10.0)

        XCTAssertTrue(FakeOnboardingAuthPostStepBeforeRegister1.wasInvoked)
        XCTAssertTrue(FakeOnboardingAuthPostStepRegister1.wasInvoked)
        XCTAssertFalse(FakeOnboardingAuthPostStepAfterRegister1.wasInvoked)
        XCTAssertFalse(FakeOnboardingAuthPostStepComplete1.wasInvoked)

        postRegister1.resolver.fulfill(())

        let expectation3 = expectation(description: "3")
        try XCTUnwrap(FakeOnboardingAuthPostStepAfterRegister1.wasInvokedPromise).done {
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 10.0)

        XCTAssertTrue(FakeOnboardingAuthPostStepBeforeRegister1.wasInvoked)
        XCTAssertTrue(FakeOnboardingAuthPostStepRegister1.wasInvoked)
        XCTAssertTrue(FakeOnboardingAuthPostStepAfterRegister1.wasInvoked)
        XCTAssertFalse(FakeOnboardingAuthPostStepComplete1.wasInvoked)

        postAfter1.resolver.fulfill(())

        let expectation4 = expectation(description: "4")
        try XCTUnwrap(FakeOnboardingAuthPostStepComplete1.wasInvokedPromise).done {
            expectation4.fulfill()
        }
        wait(for: [expectation4], timeout: 10.0)

        XCTAssertTrue(FakeOnboardingAuthPostStepBeforeRegister1.wasInvoked)
        XCTAssertTrue(FakeOnboardingAuthPostStepRegister1.wasInvoked)
        XCTAssertTrue(FakeOnboardingAuthPostStepAfterRegister1.wasInvoked)
        XCTAssertTrue(FakeOnboardingAuthPostStepComplete1.wasInvoked)

        postComplete1.resolver.fulfill(())

        XCTAssertNoThrow(try hang(result))
    }

    private func auth(
        preBeforeAuth: [Promise<Void>] = [.value(()), .value(()), .value(())],
        loginResult: Promise<String> = .value("code1"),
        tokenResult: Promise<TokenInfo> = .value(TokenInfo(
            accessToken: "access_token1",
            refreshToken: "refresh_token1",
            expiration: Date(timeIntervalSinceNow: 1000)
        )),
        postBeforeRegister: [Promise<Void>] = [.value(()), .value(()), .value(())],
        postRegister: [Promise<Void>] = [.value(()), .value(()), .value(())],
        postAfterRegister: [Promise<Void>] = [.value(()), .value(()), .value(())],
        postComplete: [Promise<Void>] = [.value(()), .value(()), .value(())]
    ) -> Promise<Void> {
        var preSteps: [OnboardingAuthPreStep.Type] = []
        var postSteps: [OnboardingAuthPostStep.Type] = []

        func combine(types: [(OnboardingAuthPreStep & FakeAuthStepResultable).Type], given: [Promise<Void>]) {
            for (idx, result) in given.enumerated() {
                types[idx].result = result
                types[idx].wasInvoked = false
                preSteps.append(types[idx])
            }
        }

        func combine(types: [(OnboardingAuthPostStep & FakeAuthStepResultable).Type], given: [Promise<Void>]) {
            for (idx, result) in given.enumerated() {
                types[idx].result = result
                types[idx].wasInvoked = false
                postSteps.append(types[idx])
            }
        }

        combine(types: [
            FakeOnboardingAuthPreStepBeforeAuth1.self,
            FakeOnboardingAuthPreStepBeforeAuth2.self,
            FakeOnboardingAuthPreStepBeforeAuth3.self,
        ], given: preBeforeAuth)

        combine(types: [
            FakeOnboardingAuthPostStepBeforeRegister1.self,
            FakeOnboardingAuthPostStepBeforeRegister2.self,
            FakeOnboardingAuthPostStepBeforeRegister3.self,
        ], given: postBeforeRegister)

        combine(types: [
            FakeOnboardingAuthPostStepRegister1.self,
            FakeOnboardingAuthPostStepRegister2.self,
            FakeOnboardingAuthPostStepRegister3.self,
        ], given: postRegister)

        combine(types: [
            FakeOnboardingAuthPostStepAfterRegister1.self,
            FakeOnboardingAuthPostStepAfterRegister2.self,
            FakeOnboardingAuthPostStepAfterRegister3.self,
        ], given: postAfterRegister)

        combine(types: [
            FakeOnboardingAuthPostStepComplete1.self,
            FakeOnboardingAuthPostStepComplete2.self,
            FakeOnboardingAuthPostStepComplete3.self,
        ], given: postComplete)

        auth.preSteps = preSteps
        auth.postSteps = postSteps

        auth.login = FakeOnboardingAuthLogin(
            expectedDetails: try? .init(baseURL: instance.internalOrExternalURL),
            result: loginResult
        )
        auth.tokenExchange = FakeOnboardingAuthTokenExchange(
            result: tokenResult,
            expectedCode: loginResult.value
        )

        return auth.authenticate(to: instance, sender: UIViewController())
    }
}

private enum TestError: Error, CancellableError {
    case any
    case specific
    case cancelled

    var isCancelled: Bool {
        if case .cancelled = self {
            return true
        } else {
            return false
        }
    }
}

protocol FakeAuthStepResultable {
    static var result: Promise<Void> { get set }
    static var wasInvoked: Bool { get set }
}

struct FakeOnboardingAuthLogin: OnboardingAuthLogin {
    func open(authDetails: OnboardingAuthDetails, sender: UIViewController) -> Promise<String> {
        XCTAssertEqual(authDetails, expectedDetails)
        return result
    }

    var expectedDetails: OnboardingAuthDetails?
    var result: Promise<String>
}

struct FakeOnboardingAuthTokenExchange: OnboardingAuthTokenExchange {
    func tokenInfo(code: String, connectionInfo: ConnectionInfo) -> Promise<TokenInfo> {
        XCTAssertEqual(code, expectedCode)
        return result
    }

    var result: Promise<TokenInfo> = .init(error: TestError.any)
    var expectedCode: String?
}

class FakeOnboardingAuthPreStep: OnboardingAuthPreStep {
    var authDetails: OnboardingAuthDetails
    var sender: UIViewController
    required init(authDetails: OnboardingAuthDetails, sender: UIViewController) {
        self.authDetails = authDetails
        self.sender = sender
    }

    class var supportedPoints: Set<OnboardingAuthStepPoint> { fatalError() }
    func perform(point: OnboardingAuthStepPoint) -> Promise<Void> { fatalError() }
}

class FakeOnboardingAuthPreStepBeforeAuth: FakeOnboardingAuthPreStep {
    override static var supportedPoints: Set<OnboardingAuthStepPoint> { Set([.beforeAuth]) }
}

class FakeOnboardingAuthPreStepBeforeAuth1: FakeOnboardingAuthPreStepBeforeAuth, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPreStepBeforeAuth2: FakeOnboardingAuthPreStepBeforeAuth, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPreStepBeforeAuth3: FakeOnboardingAuthPreStepBeforeAuth, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStep: OnboardingAuthPostStep {
    class var supportedPoints: Set<OnboardingAuthStepPoint> { fatalError() }

    var connection: HAConnection
    var api: HomeAssistantAPI
    var sender: UIViewController
    required init(connection: HAConnection, api: HomeAssistantAPI, sender: UIViewController) {
        self.connection = connection
        self.api = api
        self.sender = sender
    }

    func perform(point: OnboardingAuthStepPoint) -> Promise<Void> { fatalError() }
}

class FakeOnboardingAuthPostStepBeforeRegister: FakeOnboardingAuthPostStep {
    override static var supportedPoints: Set<OnboardingAuthStepPoint> { Set([.beforeRegister]) }
}

class FakeOnboardingAuthPostStepBeforeRegister1: FakeOnboardingAuthPostStepBeforeRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any) {
        didSet {
            (Self.wasInvokedPromise, Self.wasInvokedResolver) = Guarantee<Void>.pending()
        }
    }

    static var wasInvoked: Bool = false {
        didSet {
            if wasInvoked {
                Self.wasInvokedResolver?(())
            }
        }
    }

    static var wasInvokedPromise: Guarantee<Void>?
    static var wasInvokedResolver: ((()) -> Void)?
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepBeforeRegister2: FakeOnboardingAuthPostStepBeforeRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepBeforeRegister3: FakeOnboardingAuthPostStepBeforeRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepRegister: FakeOnboardingAuthPostStep {
    override static var supportedPoints: Set<OnboardingAuthStepPoint> { Set([.register]) }
}

class FakeOnboardingAuthPostStepRegister1: FakeOnboardingAuthPostStepRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any) {
        didSet {
            (Self.wasInvokedPromise, Self.wasInvokedResolver) = Guarantee<Void>.pending()
        }
    }

    static var wasInvoked: Bool = false {
        didSet {
            if wasInvoked {
                Self.wasInvokedResolver?(())
            }
        }
    }

    static var wasInvokedPromise: Guarantee<Void>?
    static var wasInvokedResolver: ((()) -> Void)?
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepRegister2: FakeOnboardingAuthPostStepRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepRegister3: FakeOnboardingAuthPostStepRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepAfterRegister: FakeOnboardingAuthPostStep {
    override static var supportedPoints: Set<OnboardingAuthStepPoint> { Set([.afterRegister]) }
}

class FakeOnboardingAuthPostStepAfterRegister1: FakeOnboardingAuthPostStepAfterRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any) {
        didSet {
            (Self.wasInvokedPromise, Self.wasInvokedResolver) = Guarantee<Void>.pending()
        }
    }

    static var wasInvoked: Bool = false {
        didSet {
            if wasInvoked {
                Self.wasInvokedResolver?(())
            }
        }
    }

    static var wasInvokedPromise: Guarantee<Void>?
    static var wasInvokedResolver: ((()) -> Void)?
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepAfterRegister2: FakeOnboardingAuthPostStepAfterRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepAfterRegister3: FakeOnboardingAuthPostStepAfterRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepComplete: FakeOnboardingAuthPostStep {
    override static var supportedPoints: Set<OnboardingAuthStepPoint> { Set([.complete]) }
}

class FakeOnboardingAuthPostStepComplete1: FakeOnboardingAuthPostStepComplete, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any) {
        didSet {
            (Self.wasInvokedPromise, Self.wasInvokedResolver) = Guarantee<Void>.pending()
        }
    }

    static var wasInvoked: Bool = false {
        didSet {
            if wasInvoked {
                Self.wasInvokedResolver?(())
            }
        }
    }

    static var wasInvokedPromise: Guarantee<Void>?
    static var wasInvokedResolver: ((()) -> Void)?
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepComplete2: FakeOnboardingAuthPostStepComplete, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepComplete3: FakeOnboardingAuthPostStepComplete, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}
