@testable import HomeAssistant
@testable import Shared
import XCTest

/// The connection diagnostics shown under a connection error: the state the checks report into, and the
/// checker's handling of URLs it cannot test and of a host that refuses the connection.
@MainActor
final class ConnectivityCheckerTests: XCTestCase {
    func testStateStartsWithEveryCheckPending() {
        let state = ConnectivityCheckState()

        XCTAssertEqual(state.checks.map(\.type), ConnectivityCheckType.allCases)
        XCTAssertTrue(state.checks.allSatisfy { $0.result == .pending })
        XCTAssertFalse(state.isRunning)
    }

    func testUpdatingACheckOnlyChangesThatCheck() {
        let state = ConnectivityCheckState()

        state.updateCheck(type: .port, result: .success(message: "open"))

        XCTAssertEqual(state.checks.first { $0.type == .port }?.result, .success(message: "open"))
        XCTAssertEqual(state.checks.filter { $0.result == .pending }.count, ConnectivityCheckType.allCases.count - 1)
    }

    func testResetReturnsEveryCheckToPending() {
        let state = ConnectivityCheckState()
        state.isRunning = true
        state.updateCheck(type: .dns, result: .failure(error: "no"))

        state.reset()

        XCTAssertFalse(state.isRunning)
        XCTAssertTrue(state.checks.allSatisfy { $0.result == .pending })
    }

    func testResultsReportWhetherTheyAreCompleted() {
        XCTAssertFalse(ConnectivityCheckResult.pending.isCompleted)
        XCTAssertFalse(ConnectivityCheckResult.running.isCompleted)
        XCTAssertTrue(ConnectivityCheckResult.success(message: nil).isCompleted)
        XCTAssertTrue(ConnectivityCheckResult.failure(error: "error").isCompleted)
        XCTAssertTrue(ConnectivityCheckResult.skipped.isCompleted)
    }

    func testCheckTypesHaveLocalizedNames() {
        XCTAssertEqual(ConnectivityCheckType.dns.localizedName, L10n.Connectivity.Check.dns)
        XCTAssertEqual(ConnectivityCheckType.port.localizedName, L10n.Connectivity.Check.port)
        XCTAssertEqual(ConnectivityCheckType.tls.localizedName, L10n.Connectivity.Check.tls)
        XCTAssertEqual(ConnectivityCheckType.server.localizedName, L10n.Connectivity.Check.server)
    }

    func testNewCheckDefaultsToPending() {
        XCTAssertEqual(ConnectivityCheck(type: .tls).result, .pending)
        XCTAssertEqual(ConnectivityCheck(type: .tls, result: .skipped).result, .skipped)
    }

    func testURLWithoutAHostFailsEveryCheck() async throws {
        let state = ConnectivityCheckState()
        let checker = ConnectivityChecker(state: state)
        let url = try XCTUnwrap(URL(string: "mailto:someone"))

        await checker.runChecks(for: url)

        XCTAssertFalse(state.isRunning)
        XCTAssertTrue(state.checks.allSatisfy { $0.result == .failure(error: "Invalid URL: no host found") })
    }

    /// Loopback only: the address resolves without a network, and nothing listens on port 1, so the
    /// port check fails and the checks that depend on it are skipped.
    func testRefusedPortSkipsTheRemainingChecks() async throws {
        let state = ConnectivityCheckState()
        let checker = ConnectivityChecker(state: state)
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:1"))

        await checker.runChecks(for: url)

        XCTAssertFalse(state.isRunning)
        let results = Dictionary(uniqueKeysWithValues: state.checks.map { ($0.type, $0.result) })
        guard case .success = results[.dns] else {
            return XCTFail("expected the loopback address to resolve, got \(String(describing: results[.dns]))")
        }
        guard case .failure = results[.port] else {
            return XCTFail("expected the closed port to fail, got \(String(describing: results[.port]))")
        }
        XCTAssertEqual(results[.tls], .skipped)
        XCTAssertEqual(results[.server], .skipped)
    }
}
