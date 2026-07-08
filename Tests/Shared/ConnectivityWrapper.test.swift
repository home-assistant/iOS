@testable import Shared
import XCTest

class ConnectivityWrapperTests: XCTestCase {
    private var previousCurrentNetworkState: (() async -> NetworkState)!
    private var previousLastKnownNetworkState: (() -> NetworkState)!
    private var previousRefreshNetworkInformation: (() async -> Void)!

    override func setUp() {
        super.setUp()
        previousCurrentNetworkState = Current.connectivity.currentNetworkState
        previousLastKnownNetworkState = Current.connectivity.lastKnownNetworkState
        previousRefreshNetworkInformation = Current.connectivity.refreshNetworkInformation
    }

    override func tearDown() {
        Current.connectivity.currentNetworkState = previousCurrentNetworkState
        Current.connectivity.lastKnownNetworkState = previousLastKnownNetworkState
        Current.connectivity.refreshNetworkInformation = previousRefreshNetworkInformation
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
}
