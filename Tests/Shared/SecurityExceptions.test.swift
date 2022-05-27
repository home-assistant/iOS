@testable import Shared
import UIKit
import XCTest

class SecurityExceptionsTests: XCTestCase {
    private var unitTestDotExampleDotCom1: SecTrust!
    private var unitTestDotExampleDotCom2: SecTrust!
    private var unitTestDotExampleDotCom3: SecTrust!

    private func resetSecTrusts() throws {
        unitTestDotExampleDotCom1 = try .unitTestDotExampleDotCom1
        unitTestDotExampleDotCom2 = try .unitTestDotExampleDotCom2
        unitTestDotExampleDotCom3 = try .unitTestDotExampleDotCom3

        XCTAssertFalse(SecTrustEvaluateWithError(unitTestDotExampleDotCom1, nil))
        XCTAssertFalse(SecTrustEvaluateWithError(unitTestDotExampleDotCom2, nil))
        XCTAssertFalse(SecTrustEvaluateWithError(unitTestDotExampleDotCom3, nil))
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        try resetSecTrusts()
    }

    func testWithoutAnyExceptions() throws {
        let exceptions = SecurityExceptions()
        XCTAssertThrowsError(try exceptions.evaluate(unitTestDotExampleDotCom1))
        XCTAssertThrowsError(try exceptions.evaluate(unitTestDotExampleDotCom2))
        XCTAssertThrowsError(try exceptions.evaluate(unitTestDotExampleDotCom3))
    }

    func testWithSomeExceptions() throws {
        var exceptions = SecurityExceptions()
        exceptions.add(for: unitTestDotExampleDotCom1)
        exceptions.add(for: unitTestDotExampleDotCom2)

        XCTAssertNoThrow(try exceptions.evaluate(unitTestDotExampleDotCom1))
        XCTAssertNoThrow(try exceptions.evaluate(unitTestDotExampleDotCom2))
        XCTAssertThrowsError(try exceptions.evaluate(unitTestDotExampleDotCom3))

        // should have mutated the SecTrusts as well
        XCTAssertTrue(SecTrustEvaluateWithError(unitTestDotExampleDotCom1, nil))
        XCTAssertTrue(SecTrustEvaluateWithError(unitTestDotExampleDotCom2, nil))
        XCTAssertFalse(SecTrustEvaluateWithError(unitTestDotExampleDotCom3, nil))
    }

    func testEncodeDecode() throws {
        var exceptions = SecurityExceptions()
        exceptions.add(for: unitTestDotExampleDotCom1)

        XCTAssertNoThrow(try exceptions.evaluate(unitTestDotExampleDotCom1))
        XCTAssertThrowsError(try exceptions.evaluate(unitTestDotExampleDotCom2))
        XCTAssertThrowsError(try exceptions.evaluate(unitTestDotExampleDotCom3))

        let encoder = JSONEncoder()
        let encoded = try encoder.encode(exceptions)
        let encodedEmpty = try encoder.encode(SecurityExceptions())

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SecurityExceptions.self, from: encoded)
        let decodedEmpty = try decoder.decode(SecurityExceptions.self, from: encodedEmpty)

        XCTAssertNoThrow(try decoded.evaluate(unitTestDotExampleDotCom1))
        XCTAssertThrowsError(try decoded.evaluate(unitTestDotExampleDotCom2))
        XCTAssertThrowsError(try decoded.evaluate(unitTestDotExampleDotCom3))

        try resetSecTrusts()

        XCTAssertThrowsError(try decodedEmpty.evaluate(unitTestDotExampleDotCom1))
        XCTAssertThrowsError(try decodedEmpty.evaluate(unitTestDotExampleDotCom2))
        XCTAssertThrowsError(try decodedEmpty.evaluate(unitTestDotExampleDotCom3))
    }

    func testChallengeEvaluation() throws {
        var exceptions = SecurityExceptions()
        exceptions.add(for: unitTestDotExampleDotCom1)
        exceptions.add(for: unitTestDotExampleDotCom2)

        // no real mechanism to validate the credential passed, check that the underlying SecTrust is valid is the best
        // we can do, along with making sure a credential is passed back

        let evaluate1 = exceptions.evaluate(unitTestDotExampleDotCom1.authenticationChallenge())
        XCTAssertEqual(evaluate1.0, .useCredential)
        XCTAssertNotNil(evaluate1.1)
        XCTAssertTrue(SecTrustEvaluateWithError(unitTestDotExampleDotCom1, nil))

        let evaluate2 = exceptions.evaluate(unitTestDotExampleDotCom2.authenticationChallenge())
        XCTAssertEqual(evaluate2.0, .useCredential)
        XCTAssertNotNil(evaluate2.1)
        XCTAssertTrue(SecTrustEvaluateWithError(unitTestDotExampleDotCom2, nil))

        let evaluate3 = exceptions.evaluate(unitTestDotExampleDotCom3.authenticationChallenge())
        XCTAssertEqual(evaluate3.0, .rejectProtectionSpace)
        XCTAssertNil(evaluate3.1)
        XCTAssertFalse(SecTrustEvaluateWithError(unitTestDotExampleDotCom3, nil))

        let evaluateInvalid = exceptions.evaluate(.init(
            protectionSpace: URLProtectionSpace(
                host: "UnitTest.Example.com",
                port: 443,
                protocol: nil,
                realm: nil,
                authenticationMethod: NSURLAuthenticationMethodClientCertificate
            ),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: FailingURLAuthenticationChallengeSender()
        ))
        XCTAssertEqual(evaluateInvalid.0, .performDefaultHandling, "we don't know what to do, so default")
        XCTAssertNil(evaluateInvalid.1)
    }
}
