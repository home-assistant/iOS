import HAKit
import HAKit_Mocks
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
            .unresolvedEntity(id: "light.kitchen"),
        ]

        for error in errors {
            let described = error.logDescription
            let variants = error.alertTitleVariants
            XCTAssertFalse(described.isEmpty)
            XCTAssertEqual(variants.count, 2, "Expected two variants for \(described)")
            XCTAssertFalse(variants.contains(where: \.isEmpty), "Empty variant for \(described)")
            XCTAssertGreaterThan(
                variants[0].count,
                variants[1].count,
                "Expected the longest variant first for \(described)"
            )
        }
    }

    /// The server-state branch: a reachable, ready connection means the failure is the server's or
    /// the transport's, not the drive's.
    func testAFailureOnAReadyConnectionIsNotReportedAsDisconnected() {
        let previousServers = Current.servers
        let servers = FakeServerManager()
        Current.servers = servers
        let server = servers.addFake()
        let api = HomeAssistantAPI(server: server)
        let connection = HAMockConnection()
        api.connection = connection
        Current.cachedApis[server.identifier] = api
        connection.setState(.ready(version: "1.0-mock"), waitForQueue: false)
        defer {
            Current.cachedApis = [:]
            Current.servers = previousServers
        }

        let resolved = CarPlayOperationError.resolve(
            underlying: CarPlayOperationErrorTestError.any,
            server: server
        )

        guard case .failed = resolved else {
            XCTFail("Expected a transport error to be reported as .failed on a ready connection")
            return
        }
    }

    /// A connection that exists but isn't up is still "not connected" as far as the driver goes.
    func testAFailureOnAConnectionThatIsNotReadyIsReportedAsDisconnected() {
        let previousServers = Current.servers
        let servers = FakeServerManager()
        Current.servers = servers
        let server = servers.addFake()
        let api = HomeAssistantAPI(server: server)
        let connection = HAMockConnection()
        api.connection = connection
        Current.cachedApis[server.identifier] = api
        connection.setState(.connecting, waitForQueue: false)
        defer {
            Current.cachedApis = [:]
            Current.servers = previousServers
        }

        let resolved = CarPlayOperationError.resolve(underlying: nil, server: server)

        guard case .noConnection = resolved else {
            XCTFail("Expected an unanswered action on a connecting socket to be .noConnection")
            return
        }
    }

    func testMissingServerNamesTheServerInTheLog() {
        let error = CarPlayOperationError.missingServer(id: "server-1")

        XCTAssertTrue(error.logDescription.contains("server-1"))
    }

    func testUnresolvedEntityNamesTheEntityInTheLog() {
        let error = CarPlayOperationError.unresolvedEntity(id: "light.kitchen")

        XCTAssertTrue(error.logDescription.contains("light.kitchen"))
    }
}

private enum CarPlayOperationErrorTestError: Error {
    case any
}
