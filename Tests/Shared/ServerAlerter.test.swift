import XCTest
import OHHTTPStubs
import PromiseKit
import Version
@testable import Shared

class ServerAlerterTests: XCTestCase {
    private var alerter: ServerAlerter!
    private var stubDescriptors: [HTTPStubsDescriptor] = []

    private func randomURL() -> URL {
        return URL(string: "https://example.com/\(UUID().uuidString)")!
    }

    override func setUp() {
        super.setUp()
        alerter = ServerAlerter()
    }

    private func setUp(response: Swift.Result<[ServerAlert], Error>) {
        Current.settingsStore.privacy.alerts = true

        let url = URL(string: "https://alerts.home-assistant.io/mobile.json")!
        stubDescriptors.append(stub(condition: { $0.url == url }, response: { request in
            switch response {
            case .success(let value):
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted
                return HTTPStubsResponse(
                    data: try! encoder.encode(value),
                    statusCode: 200,
                    headers: [:]
                )
            case .failure(let error):
                return HTTPStubsResponse(error: error)
            }
        }))
    }

    override func tearDown() {
        super.tearDown()
        for descriptor in stubDescriptors {
            HTTPStubs.removeStub(descriptor)
        }
    }

    func testEncoderSinceTestsRelyOnItsFormat() throws {
        let alert = ServerAlert(
            id: "id",
            date: Date(timeIntervalSince1970: 1610837683),
            url: URL(string: "http://example.com")!,
            message: "Some message",
            adminOnly: false,
            ios: .init(min: .init(major: 100, minor: 1, patch: 0), max: nil),
            core: .init(min: nil, max: .init(major: 20, minor: 0, patch: nil))
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let result = String(data: try encoder.encode(alert), encoding: .utf8)
        XCTAssertEqual(result, "{\"admin_only\":false,\"core\":{\"max\":\"20.0\",\"min\":null},\"date\":\"2021-01-16T22:54:43Z\",\"id\":\"id\",\"ios\":{\"max\":null,\"min\":\"100.1.0\"},\"message\":\"Some message\",\"url\":\"http:\\/\\/example.com\"}")
    }

    func testNoAlerts() {
        setUp(response: .success([]))
        XCTAssertThrowsError(try hang(alerter.check(dueToUserInteraction: false)))
    }

    func testAlertsDisabled() {
        setUp(response: .success([]))

        Current.settingsStore.privacy.alerts = false

        XCTAssertThrowsError(try hang(alerter.check(dueToUserInteraction: false))) { error in
            XCTAssertEqual(error as? ServerAlerter.AlerterError, .privacyDisabled)
        }

        XCTAssertThrowsError(try hang(alerter.check(dueToUserInteraction: true))) { error in
            XCTAssertNotEqual(error as? ServerAlerter.AlerterError, .privacyDisabled)
        }
    }

    func testNoVersionedAlerts() {
        Current.clientVersion = { Version(major: 100, minor: 0, patch: 0) }
        
        setUp(response: .success([
            ServerAlert(
                id: UUID().uuidString,
                date: Date(timeIntervalSinceNow: -100),
                url: randomURL(),
                message: "msg",
                adminOnly: false,
                ios: .init(min: nil, max: nil),
                core: .init(min: nil, max: nil)
            )
        ]))
        XCTAssertThrowsError(try hang(alerter.check(dueToUserInteraction: false)))
    }

    func testEarlieriOSDoesntApply() {
        Current.clientVersion = { Version(major: 100, minor: 0, patch: 0) }

        setUp(response: .success([
            ServerAlert(
                id: UUID().uuidString,
                date: Date(timeIntervalSinceNow: -100),
                url: randomURL(),
                message: "msg",
                adminOnly: false,
                ios: .init(min: .init(major: 50), max: .init(major: 99)),
                core: .init(min: nil, max: nil)
            )
        ]))
        XCTAssertThrowsError(try hang(alerter.check(dueToUserInteraction: false)))
    }

    func testLateriOSDoesntApply() {
        Current.clientVersion = { Version(major: 100, minor: 0, patch: 0) }

        setUp(response: .success([
            ServerAlert(
                id: UUID().uuidString,
                date: Date(timeIntervalSinceNow: -100),
                url: randomURL(),
                message: "msg",
                adminOnly: false,
                ios: .init(min: .init(major: 101), max: .init(major: 150)),
                core: .init(min: nil, max: nil)
            )
        ]))
        XCTAssertThrowsError(try hang(alerter.check(dueToUserInteraction: false)))
    }

    func testMiddleiOSShouldApply() {
        Current.clientVersion = { Version(major: 100, minor: 0, patch: 0) }

        let alert = ServerAlert(
            id: UUID().uuidString,
            date: Date(timeIntervalSinceNow: -100),
            url: randomURL(),
            message: "msg",
            adminOnly: false,
            ios: .init(min: .init(major: 75), max: .init(major: 125)),
            core: .init(min: nil, max: nil)
        )

        setUp(response: .success([ alert ]))
        XCTAssertEqual(try hang(alerter.check(dueToUserInteraction: false)), alert)
        // trying again should still work
        XCTAssertEqual(try hang(alerter.check(dueToUserInteraction: false)), alert)

        alerter.markHandled(alert: alert)
        XCTAssertThrowsError(try hang(alerter.check(dueToUserInteraction: false)))
    }

    func testMiddleiOSShouldApplyButNotAdmin() {
        Current.clientVersion = { Version(major: 100, minor: 0, patch: 0) }

        let alert = ServerAlert(
            id: UUID().uuidString,
            date: Date(timeIntervalSinceNow: -100),
            url: randomURL(),
            message: "msg",
            adminOnly: true,
            ios: .init(min: .init(major: 75), max: .init(major: 125)),
            core: .init(min: nil, max: nil)
        )

        Current.settingsStore.authenticatedUser = AuthenticatedUser(
            id: "123",
            name: "name",
            isOwner: false,
            isAdmin: false
        )

        setUp(response: .success([ alert ]))
        XCTAssertThrowsError(try hang(alerter.check(dueToUserInteraction: false)))

        Current.settingsStore.authenticatedUser = nil
    }

    func testLowerBoundOnlyiOSShouldApply() {
        Current.clientVersion = { Version(major: 100, minor: 0, patch: 0) }

        let alert = ServerAlert(
            id: UUID().uuidString,
            date: Date(timeIntervalSinceNow: -100),
            url: randomURL(),
            message: "msg",
            adminOnly: false,
            ios: .init(min: .init(major: 75), max: nil),
            core: .init(min: nil, max: nil)
        )

        setUp(response: .success([ alert ]))
        XCTAssertEqual(try hang(alerter.check(dueToUserInteraction: false)), alert)
        // trying again should still work
        XCTAssertEqual(try hang(alerter.check(dueToUserInteraction: false)), alert)

        alerter.markHandled(alert: alert)
        XCTAssertThrowsError(try hang(alerter.check(dueToUserInteraction: false)))
    }

    func testLowerBoundOnlyiOSShouldntApply() {
        Current.clientVersion = { Version(major: 100, minor: 0, patch: 0) }

        let alert = ServerAlert(
            id: UUID().uuidString,
            date: Date(timeIntervalSinceNow: -100),
            url: randomURL(),
            message: "msg",
            adminOnly: false,
            ios: .init(min: .init(major: 125), max: nil),
            core: .init(min: nil, max: nil)
        )

        setUp(response: .success([ alert ]))
        XCTAssertThrowsError(try hang(alerter.check(dueToUserInteraction: false)))
    }

    func testUpperBoundOnlyiOSShouldApply() {
        Current.clientVersion = { Version(major: 100, minor: 0, patch: 0) }

        let alert = ServerAlert(
            id: UUID().uuidString,
            date: Date(timeIntervalSinceNow: -100),
            url: randomURL(),
            message: "msg",
            adminOnly: false,
            ios: .init(min: nil, max: .init(major: 150)),
            core: .init(min: nil, max: nil)
        )

        setUp(response: .success([ alert ]))
        XCTAssertEqual(try hang(alerter.check(dueToUserInteraction: false)), alert)
        // trying again should still work
        XCTAssertEqual(try hang(alerter.check(dueToUserInteraction: false)), alert)

        alerter.markHandled(alert: alert)
        XCTAssertThrowsError(try hang(alerter.check(dueToUserInteraction: false)))
    }

    func testUpperBoundOnlyiOSShouldntApply() {
        Current.clientVersion = { Version(major: 100, minor: 0, patch: 0) }

        let alert = ServerAlert(
            id: UUID().uuidString,
            date: Date(timeIntervalSinceNow: -100),
            url: randomURL(),
            message: "msg",
            adminOnly: false,
            ios: .init(min: nil, max: .init(major: 99)),
            core: .init(min: nil, max: nil)
        )

        setUp(response: .success([ alert ]))
        XCTAssertThrowsError(try hang(alerter.check(dueToUserInteraction: false)))
    }

    func testEarlierCoreDoesntApply() {
        Current.serverVersion = { Version(major: 100, minor: 0, patch: 0) }

        setUp(response: .success([
            ServerAlert(
                id: UUID().uuidString,
                date: Date(timeIntervalSinceNow: -100),
                url: randomURL(),
                message: "msg",
                adminOnly: false,
                ios: .init(min: nil, max: nil),
                core: .init(min: .init(major: 50), max: .init(major: 99))
            )
        ]))
        XCTAssertThrowsError(try hang(alerter.check(dueToUserInteraction: false)))
    }

    func testLaterCoreDoesntApply() {
        Current.serverVersion = { Version(major: 100, minor: 0, patch: 0) }

        setUp(response: .success([
            ServerAlert(
                id: UUID().uuidString,
                date: Date(timeIntervalSinceNow: -100),
                url: randomURL(),
                message: "msg",
                adminOnly: false,
                ios: .init(min: nil, max: nil),
                core: .init(min: .init(major: 101), max: .init(major: 150))
            )
        ]))
        XCTAssertThrowsError(try hang(alerter.check(dueToUserInteraction: false)))
    }

    func testMiddleCoreShouldApply() {
        Current.serverVersion = { Version(major: 100, minor: 0, patch: 0) }

        let alert = ServerAlert(
            id: UUID().uuidString,
            date: Date(timeIntervalSinceNow: -100),
            url: randomURL(),
            message: "msg",
            adminOnly: false,
            ios: .init(min: nil, max: nil),
            core: .init(min: .init(major: 75), max: .init(major: 125))
        )

        setUp(response: .success([ alert ]))
        XCTAssertEqual(try hang(alerter.check(dueToUserInteraction: false)), alert)
        // trying again should still work
        XCTAssertEqual(try hang(alerter.check(dueToUserInteraction: false)), alert)

        alerter.markHandled(alert: alert)
        XCTAssertThrowsError(try hang(alerter.check(dueToUserInteraction: false)))
    }

    func testMultipleApplyGivesFirst() {
        Current.serverVersion = { Version(major: 100, minor: 0, patch: 0) }
        Current.clientVersion = { Version(major: 100, minor: 0, patch: 0) }

        let alerts = [
            ServerAlert(
                id: UUID().uuidString,
                date: Date(timeIntervalSinceNow: -100),
                url: randomURL(),
                message: "msg1",
                adminOnly: false,
                ios: .init(min: .init(major: 75), max: .init(major: 125)),
                core: .init(min: nil, max: nil)
            ),
            ServerAlert(
                id: UUID().uuidString,
                date: Date(timeIntervalSinceNow: -100),
                url: randomURL(),
                message: "msg2",
                adminOnly: false,
                ios: .init(min: nil, max: nil),
                core: .init(min: .init(major: 75), max: .init(major: 125))
            )
        ]

        setUp(response: .success(alerts))
        XCTAssertEqual(try hang(alerter.check(dueToUserInteraction: false)), alerts[0])
        alerter.markHandled(alert: alerts[0])
        XCTAssertEqual(try hang(alerter.check(dueToUserInteraction: false)), alerts[1])
    }

    func testErroredRequestsDoesntAlert() {
        let expectedError = URLError(.timedOut)
        setUp(response: .failure(expectedError))
        XCTAssertThrowsError(try hang(alerter.check(dueToUserInteraction: false))) { error in
            XCTAssertEqual((error as? URLError)?.code, expectedError.code)
        }
    }
}
