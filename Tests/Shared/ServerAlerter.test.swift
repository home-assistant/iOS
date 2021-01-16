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
        let url = URL(string: "https://companion.home-assistant.io/alerts.json")!
        stubDescriptors.append(stub(condition: { $0.url == url }, response: { request in
            switch response {
            case .success(let value):
                let encoder = JSONEncoder()
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
            url: URL(string: "http://example.com")!,
            message: "Some message",
            ios: .init(min: .init(major: 100, minor: 1, patch: 0), max: nil),
            core: .init(min: nil, max: .init(major: 20, minor: 0, patch: nil))
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let result = String(data: try encoder.encode(alert), encoding: .utf8)
        XCTAssertEqual(result, "{\"core\":{\"max\":\"20.0\",\"min\":null},\"ios\":{\"max\":null,\"min\":\"100.1.0\"},\"message\":\"Some message\",\"url\":\"http:\\/\\/example.com\"}")
    }

    func testNoAlerts() {
        setUp(response: .success([]))
        XCTAssertThrowsError(try hang(alerter.check()))
    }

    func testNoVersionedAlerts() {
        Current.clientVersion = { Version(major: 100, minor: 0, patch: 0) }
        
        setUp(response: .success([
            ServerAlert(
                url: randomURL(),
                message: "msg",
                ios: .init(min: nil, max: nil),
                core: .init(min: nil, max: nil)
            )
        ]))
        XCTAssertThrowsError(try hang(alerter.check()))
    }

    func testEarlieriOSDoesntApply() {
        Current.clientVersion = { Version(major: 100, minor: 0, patch: 0) }

        setUp(response: .success([
            ServerAlert(
                url: randomURL(),
                message: "msg",
                ios: .init(min: .init(major: 50), max: .init(major: 99)),
                core: .init(min: nil, max: nil)
            )
        ]))
        XCTAssertThrowsError(try hang(alerter.check()))
    }

    func testLateriOSDoesntApply() {
        Current.clientVersion = { Version(major: 100, minor: 0, patch: 0) }

        setUp(response: .success([
            ServerAlert(
                url: randomURL(),
                message: "msg",
                ios: .init(min: .init(major: 101), max: .init(major: 150)),
                core: .init(min: nil, max: nil)
            )
        ]))
        XCTAssertThrowsError(try hang(alerter.check()))
    }

    func testMiddleiOSShouldApply() {
        Current.clientVersion = { Version(major: 100, minor: 0, patch: 0) }

        let alert = ServerAlert(
            url: randomURL(),
            message: "msg",
            ios: .init(min: .init(major: 75), max: .init(major: 125)),
            core: .init(min: nil, max: nil)
        )

        setUp(response: .success([ alert ]))
        XCTAssertEqual(try hang(alerter.check()), alert)
        // trying again should still work
        XCTAssertEqual(try hang(alerter.check()), alert)

        alerter.markHandled(alert: alert)
        XCTAssertThrowsError(try hang(alerter.check()))
    }

    func testEarlierCoreDoesntApply() {
        Current.serverVersion = { Version(major: 100, minor: 0, patch: 0) }

        setUp(response: .success([
            ServerAlert(
                url: randomURL(),
                message: "msg",
                ios: .init(min: nil, max: nil),
                core: .init(min: .init(major: 50), max: .init(major: 99))
            )
        ]))
        XCTAssertThrowsError(try hang(alerter.check()))
    }

    func testLaterCoreDoesntApply() {
        Current.serverVersion = { Version(major: 100, minor: 0, patch: 0) }

        setUp(response: .success([
            ServerAlert(
                url: randomURL(),
                message: "msg",
                ios: .init(min: nil, max: nil),
                core: .init(min: .init(major: 101), max: .init(major: 150))
            )
        ]))
        XCTAssertThrowsError(try hang(alerter.check()))
    }

    func testMiddleCoreShouldApply() {
        Current.serverVersion = { Version(major: 100, minor: 0, patch: 0) }

        let alert = ServerAlert(
            url: randomURL(),
            message: "msg",
            ios: .init(min: nil, max: nil),
            core: .init(min: .init(major: 75), max: .init(major: 125))
        )

        setUp(response: .success([ alert ]))
        XCTAssertEqual(try hang(alerter.check()), alert)
        // trying again should still work
        XCTAssertEqual(try hang(alerter.check()), alert)

        alerter.markHandled(alert: alert)
        XCTAssertThrowsError(try hang(alerter.check()))
    }

    func testMultipleApplyGivesFirst() {
        Current.serverVersion = { Version(major: 100, minor: 0, patch: 0) }
        Current.clientVersion = { Version(major: 100, minor: 0, patch: 0) }

        let alerts = [
            ServerAlert(
                url: randomURL(),
                message: "msg1",
                ios: .init(min: .init(major: 75), max: .init(major: 125)),
                core: .init(min: nil, max: nil)
            ),
            ServerAlert(
                url: randomURL(),
                message: "msg2",
                ios: .init(min: nil, max: nil),
                core: .init(min: .init(major: 75), max: .init(major: 125))
            )
        ]

        setUp(response: .success(alerts))
        XCTAssertEqual(try hang(alerter.check()), alerts[0])
        alerter.markHandled(alert: alerts[0])
        XCTAssertEqual(try hang(alerter.check()), alerts[1])
    }
}
