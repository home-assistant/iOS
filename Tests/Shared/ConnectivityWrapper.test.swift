@testable import Shared
import XCTest

class ConnectivityWrapperTests: XCTestCase {
    private var previousCurrentNetworkState: (() async -> NetworkState)!
    private var previousLastKnownNetworkState: (() -> NetworkState)!
    private var previousRefreshNetworkInformation: (() async -> Void)!
    private var previousPerformNetworkStateFetch: (() async -> NetworkState)!
    private var previousNetworkFetchTimeout: TimeInterval!
    private var previousSimpleNetworkType: (() -> NetworkType)!
    private var previousEmptyNetworkStateGrace: TimeInterval!
    private var previousDate: (() -> Date)!

    override func setUp() {
        super.setUp()
        previousCurrentNetworkState = Current.connectivity.currentNetworkState
        previousLastKnownNetworkState = Current.connectivity.lastKnownNetworkState
        previousRefreshNetworkInformation = Current.connectivity.refreshNetworkInformation
        previousPerformNetworkStateFetch = Current.connectivity.performNetworkStateFetch
        previousNetworkFetchTimeout = Current.connectivity.networkFetchTimeout
        previousSimpleNetworkType = Current.connectivity.simpleNetworkType
        previousEmptyNetworkStateGrace = Current.connectivity.emptyNetworkStateGrace
        previousDate = Current.date
        Current.connectivity.updateLastKnownNetworkState(NetworkState())
    }

    override func tearDown() {
        Current.connectivity.currentNetworkState = previousCurrentNetworkState
        Current.connectivity.lastKnownNetworkState = previousLastKnownNetworkState
        Current.connectivity.refreshNetworkInformation = previousRefreshNetworkInformation
        Current.connectivity.performNetworkStateFetch = previousPerformNetworkStateFetch
        Current.connectivity.networkFetchTimeout = previousNetworkFetchTimeout
        Current.connectivity.simpleNetworkType = previousSimpleNetworkType
        Current.connectivity.emptyNetworkStateGrace = previousEmptyNetworkStateGrace
        Current.date = previousDate
        Current.connectivity.updateLastKnownNetworkState(NetworkState())
        super.tearDown()
    }

    func testNetworkStateDefaultsAreNil() {
        let state = NetworkState()
        XCTAssertNil(state.ssid)
        XCTAssertNil(state.bssid)
        XCTAssertNil(state.hardwareAddress)
    }

    func testNetworkStateEquality() {
        XCTAssertEqual(
            NetworkState(ssid: "a", bssid: "b", hardwareAddress: "c"),
            NetworkState(ssid: "a", bssid: "b", hardwareAddress: "c")
        )
        XCTAssertNotEqual(NetworkState(ssid: "a"), NetworkState(ssid: "b"))
        XCTAssertNotEqual(NetworkState(bssid: "a"), NetworkState())
        XCTAssertNotEqual(NetworkState(hardwareAddress: "a"), NetworkState())
    }

    func testCurrentWiFiAccessorsReadFreshNetworkState() async {
        Current.connectivity.currentNetworkState = {
            NetworkState(ssid: "some-ssid", bssid: "some-bssid", hardwareAddress: "some-mac")
        }

        let ssid = await Current.connectivity.currentWiFiSSID()
        let bssid = await Current.connectivity.currentWiFiBSSID()
        let hardwareAddress = await Current.connectivity.currentNetworkHardwareAddress()

        XCTAssertEqual(ssid, "some-ssid")
        XCTAssertEqual(bssid, "some-bssid")
        XCTAssertEqual(hardwareAddress, "some-mac")
    }

    func testUpdateLastKnownNetworkStateIsReadableSynchronously() {
        Current.connectivity.updateLastKnownNetworkState(
            NetworkState(ssid: "cached-ssid", bssid: "cached-bssid")
        )

        let state = Current.connectivity.lastKnownNetworkState()
        XCTAssertEqual(state.ssid, "cached-ssid")
        XCTAssertEqual(state.bssid, "cached-bssid")
    }

    func testRefreshNetworkInformationUpdatesLastKnownState() async {
        Current.connectivity.currentNetworkState = { NetworkState(ssid: "fetched-ssid") }

        await Current.connectivity.refreshNetworkInformation()

        XCTAssertEqual(Current.connectivity.lastKnownNetworkState().ssid, "fetched-ssid")
    }

    func testFetchThatTimesOutPreservesLastKnownState() async {
        Current.connectivity.updateLastKnownNetworkState(
            NetworkState(ssid: "cached-ssid", bssid: "cached-bssid")
        )
        Current.connectivity.networkFetchTimeout = 0.1
        Current.connectivity.performNetworkStateFetch = {
            try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
            return NetworkState(ssid: "should-not-be-used")
        }

        let state = await Current.connectivity.fetchNetworkState()

        XCTAssertEqual(state.ssid, "cached-ssid")
        XCTAssertEqual(state.bssid, "cached-bssid")
        XCTAssertEqual(Current.connectivity.lastKnownNetworkState().ssid, "cached-ssid")
    }

    func testFetchThatNeverCompletesTimesOutToLastKnownState() async {
        Current.connectivity.updateLastKnownNetworkState(NetworkState(ssid: "cached-ssid"))
        Current.connectivity.networkFetchTimeout = 0.1
        Current.connectivity.performNetworkStateFetch = {
            // Simulates NEHotspotNetwork never calling back (seen during background launches).
            try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            return NetworkState(ssid: "should-not-be-used")
        }

        let state = await Current.connectivity.fetchNetworkState()

        XCTAssertEqual(state.ssid, "cached-ssid")
    }

    func testFetchCompletingAfterTimeoutDoesNotOverrideLastKnownState() async throws {
        Current.connectivity.updateLastKnownNetworkState(NetworkState(ssid: "cached-ssid"))
        Current.connectivity.networkFetchTimeout = 0.1
        Current.connectivity.performNetworkStateFetch = {
            try? await Task.sleep(nanoseconds: 500_000_000)
            return NetworkState(ssid: "late-ssid")
        }

        let state = await Current.connectivity.fetchNetworkState()
        XCTAssertEqual(state.ssid, "cached-ssid")

        // The fetch that lost the race must be dropped entirely, not applied after the fact.
        try await Task.sleep(nanoseconds: 1_000_000_000)
        XCTAssertEqual(Current.connectivity.lastKnownNetworkState().ssid, "cached-ssid")
    }

    func testPathUpdateMovingToAnotherWiFiNetworkPostsConnectivityChange() async {
        Current.connectivity.simpleNetworkType = { .wifi }
        Current.connectivity.currentNetworkState = { NetworkState(ssid: "home", bssid: "home-bssid") }
        await Current.connectivity.handleNetworkPathUpdate()

        Current.connectivity.currentNetworkState = { NetworkState(ssid: "hotspot", bssid: "hotspot-bssid") }
        let expectation = expectation(
            forNotification: Current.connectivity.connectivityDidChangeNotification(),
            object: nil
        )

        await Current.connectivity.handleNetworkPathUpdate()

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertEqual(Current.connectivity.lastKnownNetworkState().ssid, "hotspot")
    }

    func testPathUpdateOnTheSameNetworkDoesNotPostConnectivityChange() async {
        Current.connectivity.simpleNetworkType = { .wifi }
        Current.connectivity.currentNetworkState = { NetworkState(ssid: "home", bssid: "home-bssid") }
        await Current.connectivity.handleNetworkPathUpdate()

        let expectation = expectation(
            forNotification: Current.connectivity.connectivityDidChangeNotification(),
            object: nil
        )
        expectation.isInverted = true

        await Current.connectivity.handleNetworkPathUpdate()

        await fulfillment(of: [expectation], timeout: 0.5)
    }

    func testPathUpdateNotifiesEvenWhenAnotherRefreshCachedTheNewNetworkFirst() async {
        Current.connectivity.simpleNetworkType = { .wifi }
        Current.connectivity.currentNetworkState = { NetworkState(ssid: "home") }
        await Current.connectivity.handleNetworkPathUpdate()

        // Another caller, e.g. a webhook send, refreshed the cache to the new network first.
        Current.connectivity.currentNetworkState = { NetworkState(ssid: "hotspot") }
        Current.connectivity.updateLastKnownNetworkState(NetworkState(ssid: "hotspot"))

        let expectation = expectation(
            forNotification: Current.connectivity.connectivityDidChangeNotification(),
            object: nil
        )

        await Current.connectivity.handleNetworkPathUpdate()

        await fulfillment(of: [expectation], timeout: 1)
    }

    func testPathUpdateChangingNetworkTypePostsConnectivityChange() async {
        Current.connectivity.simpleNetworkType = { .wifi }
        Current.connectivity.currentNetworkState = { NetworkState(ssid: "home") }
        await Current.connectivity.handleNetworkPathUpdate()

        Current.connectivity.simpleNetworkType = { .cellular }
        Current.connectivity.currentNetworkState = { NetworkState() }
        let expectation = expectation(
            forNotification: Current.connectivity.connectivityDidChangeNotification(),
            object: nil
        )

        await Current.connectivity.handleNetworkPathUpdate()

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertNil(Current.connectivity.lastKnownNetworkState().ssid)
    }

    func testFetchThatCompletesUpdatesLastKnownState() async {
        Current.connectivity.updateLastKnownNetworkState(NetworkState(ssid: "stale-ssid"))
        Current.connectivity.networkFetchTimeout = 5
        Current.connectivity.performNetworkStateFetch = {
            NetworkState(ssid: "fresh-ssid", bssid: "fresh-bssid")
        }

        let state = await Current.connectivity.fetchNetworkState()

        XCTAssertEqual(state.ssid, "fresh-ssid")
        XCTAssertEqual(state.bssid, "fresh-bssid")
        XCTAssertEqual(Current.connectivity.lastKnownNetworkState().ssid, "fresh-ssid")
    }

    func testEmptyFetchWhileStillOnWiFiKeepsLastKnownNetwork() async {
        Current.connectivity.simpleNetworkType = { .wifi }
        Current.connectivity.performNetworkStateFetch = { NetworkState(ssid: "home", bssid: "ap-a") }
        _ = await Current.connectivity.fetchNetworkState()

        // Roaming to another access point on the same SSID: NEHotspotNetwork reports nothing while the
        // device re-associates, which must not read as having left the network.
        Current.connectivity.performNetworkStateFetch = { NetworkState() }

        let state = await Current.connectivity.fetchNetworkState()

        XCTAssertEqual(state.ssid, "home")
        XCTAssertEqual(state.bssid, "ap-a")
        XCTAssertEqual(Current.connectivity.lastKnownNetworkState().ssid, "home")
    }

    func testEmptyFetchOnCellularClearsLastKnownNetwork() async {
        Current.connectivity.simpleNetworkType = { .wifi }
        Current.connectivity.performNetworkStateFetch = { NetworkState(ssid: "home", bssid: "ap-a") }
        _ = await Current.connectivity.fetchNetworkState()

        Current.connectivity.simpleNetworkType = { .cellular }
        Current.connectivity.performNetworkStateFetch = { NetworkState() }

        let state = await Current.connectivity.fetchNetworkState()

        XCTAssertNil(state.ssid)
        XCTAssertNil(Current.connectivity.lastKnownNetworkState().ssid)
    }

    func testEmptyFetchIsBelievedOnceTheGraceElapses() async {
        var now = Date(timeIntervalSince1970: 1_000_000)
        Current.date = { now }
        Current.connectivity.simpleNetworkType = { .wifi }
        Current.connectivity.emptyNetworkStateGrace = 60
        Current.connectivity.performNetworkStateFetch = { NetworkState(ssid: "home") }
        _ = await Current.connectivity.fetchNetworkState()

        Current.connectivity.performNetworkStateFetch = { NetworkState() }
        now = now.addingTimeInterval(59)
        let withinGrace = await Current.connectivity.fetchNetworkState()
        XCTAssertEqual(withinGrace.ssid, "home")

        now = now.addingTimeInterval(2)
        let pastGrace = await Current.connectivity.fetchNetworkState()
        XCTAssertNil(pastGrace.ssid)
    }

    func testRepeatedEmptyFetchesDoNotExtendTheGrace() async {
        var now = Date(timeIntervalSince1970: 1_000_000)
        Current.date = { now }
        Current.connectivity.simpleNetworkType = { .wifi }
        Current.connectivity.emptyNetworkStateGrace = 60
        Current.connectivity.performNetworkStateFetch = { NetworkState(ssid: "home") }
        _ = await Current.connectivity.fetchNetworkState()

        // The grace is measured from the last fetch that actually reported a network, so preserving the
        // cached one must not push the deadline out on every retry.
        Current.connectivity.performNetworkStateFetch = { NetworkState() }
        for _ in 0 ..< 6 {
            now = now.addingTimeInterval(10)
            _ = await Current.connectivity.fetchNetworkState()
        }

        XCTAssertNil(Current.connectivity.lastKnownNetworkState().ssid)
    }

    func testEmptyFetchWithNoPriorNetworkIsBelieved() async {
        Current.connectivity.simpleNetworkType = { .wifi }
        Current.connectivity.performNetworkStateFetch = { NetworkState() }

        let state = await Current.connectivity.fetchNetworkState()

        XCTAssertNil(state.ssid)
    }

    func testRefreshingWhileTheNetworkIsUnreadableKeepsReportingTheSameNetwork() async {
        Current.connectivity.simpleNetworkType = { .wifi }
        Current.connectivity.currentNetworkState = { await Current.connectivity.fetchNetworkState() }
        Current.connectivity.performNetworkStateFetch = { NetworkState(ssid: "home", bssid: "ap-a") }
        await Current.connectivity.refreshNetworkInformation()

        Current.connectivity.performNetworkStateFetch = { NetworkState() }
        await Current.connectivity.refreshNetworkInformation()

        XCTAssertEqual(Current.connectivity.lastKnownNetworkState().ssid, "home")
    }

    func testPathUpdateWhileRoamingDoesNotPostConnectivityChange() async {
        Current.connectivity.simpleNetworkType = { .wifi }
        Current.connectivity.currentNetworkState = { await Current.connectivity.fetchNetworkState() }
        Current.connectivity.performNetworkStateFetch = { NetworkState(ssid: "home", bssid: "ap-a") }
        await Current.connectivity.handleNetworkPathUpdate()

        Current.connectivity.performNetworkStateFetch = { NetworkState() }
        let expectation = expectation(
            forNotification: Current.connectivity.connectivityDidChangeNotification(),
            object: nil
        )
        expectation.isInverted = true

        await Current.connectivity.handleNetworkPathUpdate()

        await fulfillment(of: [expectation], timeout: 0.5)
        XCTAssertEqual(Current.connectivity.lastKnownNetworkState().ssid, "home")
    }
}
