@testable import HomeAssistant
@testable import Shared
import XCTest

final class CarPlayOperationErrorTests: XCTestCase {
    /// `ServerFixture.standard` carries no reachable URL, so `Current.api(for:)` yields nil — the
    /// same thing a car sees when the connection is gone.
    private let disconnectedServer = ServerFixture.standard

    func testAFailureWithoutAConnectionIsReportedAsDisconnected() {
        let underlying = CarPlayOperationErrorTestError.any
        let resolved = CarPlayOperationError.resolve(underlying: underlying, server: disconnectedServer)

        guard case .noConnection = resolved else {
            XCTFail("Expected a transport error to be reported as .noConnection while offline")
            return
        }
    }

    func testAnUnansweredActionWithoutAConnectionIsReportedAsDisconnected() {
        let resolved = CarPlayOperationError.resolve(underlying: nil, server: disconnectedServer)

        guard case .noConnection = resolved else {
            XCTFail("Expected an unanswered action to be reported as .noConnection while offline")
            return
        }
    }

    func testAReportedErrorOnALiveConnectionIsReportedAsAFailure() {
        let underlying = CarPlayOperationErrorTestError.any
        let resolved = CarPlayOperationError.resolve(underlying: underlying, isConnected: true)

        guard case .failed = resolved else {
            XCTFail("Expected a transport error to be reported as .failed while connected")
            return
        }
    }

    func testAnUnansweredActionOnALiveConnectionIsReportedAsATimeout() {
        let resolved = CarPlayOperationError.resolve(underlying: nil, isConnected: true)

        guard case .timedOut = resolved else {
            XCTFail("Expected an unanswered action to be reported as .timedOut while connected")
            return
        }
    }

    /// CarPlay renders the longest variant its display can fit, so every case has to offer a short
    /// one and the long one has to come first.
    func testEveryCaseOffersTitleVariantsLongestFirst() {
        let errors: [CarPlayOperationError] = [
            .noConnection,
            .timedOut,
            .failed(CarPlayOperationErrorTestError.any),
            .missingServer(id: "123"),
        ]

        for error in errors {
            let variants = error.alertTitleVariants
            XCTAssertEqual(variants.count, 2, "Expected two variants for \(error.logDescription)")
            XCTAssertFalse(variants.contains(where: \.isEmpty), "Empty variant for \(error.logDescription)")
            XCTAssertGreaterThan(
                variants[0].count,
                variants[1].count,
                "Expected the longest variant first for \(error.logDescription)"
            )
        }
    }

    func testMissingServerNamesTheServerInTheLog() {
        let error = CarPlayOperationError.missingServer(id: "server-1")

        XCTAssertTrue(error.logDescription.contains("server-1"))
    }
}

private enum CarPlayOperationErrorTestError: Error {
    case any
}
