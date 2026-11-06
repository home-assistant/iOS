import HAKit
import HAKit_Mocks
@testable import Shared
import XCTest

/// HAKit never times out a connect, so a socket whose connect never calls back sits in
/// `.connecting` for good, and `connect()` is a no-op while it exists. The periodic connect is where
/// the app notices and starts the socket over.
final class HAAPIStuckWebSocketConnectTests: XCTestCase {
    private var now: Date!
    private var previousDate: (() -> Date)!
    private var api: HomeAssistantAPI!
    private var connection: RecordingConnection!

    override func setUp() {
        super.setUp()
        now = Date(timeIntervalSince1970: 1_700_000_000)
        previousDate = Current.date
        Current.date = { [weak self] in self?.now ?? Date() }
        api = HomeAssistantAPI(server: .fake())
        connection = RecordingConnection()
        api.connection = connection
        connection.delegate = api
    }

    override func tearDown() {
        Current.date = previousDate
        api = nil
        connection = nil
        super.tearDown()
    }

    func testAConnectThatOutlivesTheTimeoutIsStartedOver() {
        connection.setState(.connecting)
        drainMainQueue()

        now = now.addingTimeInterval(HomeAssistantAPI.stuckWebSocketConnectTimeout)
        api.connectWebSocketIfNeeded()

        XCTAssertEqual(connection.disconnectCount, 1)
        XCTAssertEqual(connection.connectCount, 1)
    }

    /// A slow handshake is not a dead one: inside the budget the periodic connect keeps nudging HAKit
    /// the way it always has, without dropping the socket.
    func testAConnectStillInsideTheTimeoutIsLeftAlone() {
        connection.setState(.connecting)
        drainMainQueue()

        now = now.addingTimeInterval(HomeAssistantAPI.stuckWebSocketConnectTimeout - 1)
        api.connectWebSocketIfNeeded()

        XCTAssertEqual(connection.disconnectCount, 0)
        XCTAssertEqual(connection.connectCount, 1)
    }

    /// The clock only counts a single uninterrupted stay in `.connecting`: a socket that connected in
    /// between and is connecting again starts a fresh budget.
    func testTheBudgetRestartsAfterTheSocketCameBack() {
        connection.setState(.connecting)
        drainMainQueue()
        now = now.addingTimeInterval(HomeAssistantAPI.stuckWebSocketConnectTimeout - 1)
        connection.setState(.ready(version: "1.0-mock"))
        drainMainQueue()
        connection.setState(.connecting)
        drainMainQueue()

        now = now.addingTimeInterval(2)
        api.connectWebSocketIfNeeded()

        XCTAssertEqual(connection.disconnectCount, 0)
        XCTAssertEqual(connection.connectCount, 1)
    }

    /// Starting over clears the clock, so the next periodic connect does not tear down the socket
    /// that is just beginning its new attempt.
    func testStartingOverResetsTheClock() {
        connection.setState(.connecting)
        drainMainQueue()
        now = now.addingTimeInterval(HomeAssistantAPI.stuckWebSocketConnectTimeout)
        api.connectWebSocketIfNeeded()
        drainMainQueue()

        now = now.addingTimeInterval(1)
        api.connectWebSocketIfNeeded()

        XCTAssertEqual(connection.disconnectCount, 1)
        XCTAssertEqual(connection.connectCount, 2)
    }

    private func drainMainQueue(cycles: Int = 2) {
        let expectation = expectation(description: "drain main queue")

        func schedule(_ remaining: Int) {
            DispatchQueue.main.async {
                if remaining == 0 {
                    expectation.fulfill()
                } else {
                    schedule(remaining - 1)
                }
            }
        }

        schedule(cycles)
        wait(for: [expectation], timeout: 10.0)
    }
}

/// A connection whose state the test sets directly and that records what the API asks of it;
/// `HAMockConnection` connects itself to ready on `connect()`, which hides the no-op this guards.
private final class RecordingConnection: HAConnection {
    weak var delegate: HAConnectionDelegate?
    var configuration: HAConnectionConfiguration = .fake
    var callbackQueue: DispatchQueue = .main
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0
    lazy var caches: HACachesContainer = .init(connection: self)

    private(set) var state: HAConnectionState = .disconnected(reason: .disconnected) {
        didSet {
            callbackQueue.async { [self, state] in
                delegate?.connection(self, didTransitionTo: state)
            }
        }
    }

    func setState(_ state: HAConnectionState) {
        self.state = state
    }

    func connect() {
        connectCount += 1
    }

    func disconnect() {
        disconnectCount += 1
        state = .disconnected(reason: .disconnected)
    }

    private func noopCancellable() -> HACancellable {
        HAMockCancellable {}
    }

    func send(_ request: HARequest, completion: @escaping (Swift.Result<HAData, HAError>) -> Void) -> HACancellable {
        noopCancellable()
    }

    func send<T>(
        _ request: HATypedRequest<T>,
        completion: @escaping (Swift.Result<T, HAError>) -> Void
    ) -> HACancellable {
        noopCancellable()
    }

    func subscribe(
        to request: HARequest,
        handler: @escaping (HACancellable, HAData) -> Void
    ) -> HACancellable {
        noopCancellable()
    }

    func subscribe(
        to request: HARequest,
        initiated: @escaping (Swift.Result<HAData, HAError>) -> Void,
        handler: @escaping (HACancellable, HAData) -> Void
    ) -> HACancellable {
        noopCancellable()
    }

    func subscribe<T>(
        to request: HATypedSubscription<T>,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        noopCancellable()
    }

    func subscribe<T>(
        to request: HATypedSubscription<T>,
        initiated: @escaping (Swift.Result<HAData, HAError>) -> Void,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        noopCancellable()
    }
}
