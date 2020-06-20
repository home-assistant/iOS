import Foundation
import PromiseKit
import CoreTelephony
@testable import Shared
import XCTest

// swiftlint:disable large_tuple

class WebhookSensorConnectivityTests: XCTestCase {
    private func setUp(
        ssid: String?,
        bssid: String?,
        networkType: NetworkType,
        cellularNetworkType: NetworkType?,
        cellular: [String: CTCarrier]? = nil,
        radioTech: [String: String]? = nil
    ) throws -> (ssid: WebhookSensor?, bssid: WebhookSensor?, connection: WebhookSensor?, sims: [WebhookSensor]) {
        Current.connectivity.currentWiFiSSID = { ssid }
        Current.connectivity.currentWiFiBSSID = { bssid }
        Current.connectivity.simpleNetworkType = { networkType }
        Current.connectivity.cellularNetworkType = { cellularNetworkType ?? networkType }
        Current.connectivity.telephonyCarriers = { cellular }
        Current.connectivity.telephonyRadioAccessTechnology = { radioTech }

        let promise = WebhookSensor.connectivity()
        let sensors = try hang(promise)

        return (
            ssid: sensors.first(where: { $0.UniqueID == "connectivity_ssid" }),
            bssid: sensors.first(where: { $0.UniqueID == "connectivity_bssid" }),
            connection: sensors.first(where: { $0.UniqueID == "connectivity_connection_type" }),
            sims: sensors.filter {
                $0.UniqueID?.contains("sim") == true || $0.UniqueID?.contains("cellular") == true
            }.sorted(by: { lhs, rhs in (lhs.UniqueID ?? "") < (rhs.UniqueID ?? "") })
        )
    }

    func testNoWifiNoCellular() throws {
        let s = try setUp(
            ssid: nil,
            bssid: nil,
            networkType: .noConnection,
            cellularNetworkType: nil
        )

        XCTAssertEqual(s.ssid?.UniqueID, "connectivity_ssid")
        XCTAssertEqual(s.ssid?.Name, "SSID")
        XCTAssertEqual(s.ssid?.State as? String, "Not Connected")
        XCTAssertEqual(s.ssid?.Icon, "mdi:wifi-off")

        XCTAssertEqual(s.bssid?.UniqueID, "connectivity_bssid")
        XCTAssertEqual(s.bssid?.Name, "BSSID")
        XCTAssertEqual(s.bssid?.State as? String, "Not Connected")
        XCTAssertEqual(s.bssid?.Icon, "mdi:wifi-off")

        XCTAssertEqual(s.connection?.UniqueID, "connectivity_connection_type")
        XCTAssertEqual(s.connection?.Name, "Connection Type")
        XCTAssertEqual(s.connection?.State as? String, "No Connection")
        XCTAssertEqual(s.connection?.Icon, "mdi:sim-off")

        XCTAssertEqual(s.sims.count, 0)
    }

    func testWifiNoCellular() throws {
        let s = try setUp(
            ssid: "Bob's Burgers Guest Wi-Fi",
            bssid: "ff:ee:dd:cc:bb:aa",
            networkType: .wifi,
            cellularNetworkType: nil
        )

        XCTAssertEqual(s.ssid?.UniqueID, "connectivity_ssid")
        XCTAssertEqual(s.ssid?.Name, "SSID")
        XCTAssertEqual(s.ssid?.State as? String, "Bob's Burgers Guest Wi-Fi")
        XCTAssertEqual(s.ssid?.Icon, "mdi:wifi")

        XCTAssertEqual(s.bssid?.UniqueID, "connectivity_bssid")
        XCTAssertEqual(s.bssid?.Name, "BSSID")
        XCTAssertEqual(s.bssid?.State as? String, "ff:ee:dd:cc:bb:aa")
        XCTAssertEqual(s.bssid?.Icon, "mdi:wifi-star")

        XCTAssertEqual(s.connection?.UniqueID, "connectivity_connection_type")
        XCTAssertEqual(s.connection?.Name, "Connection Type")
        XCTAssertEqual(s.connection?.State as? String, "Wi-Fi")
        XCTAssertEqual(s.connection?.Icon, "mdi:wifi")

        XCTAssertEqual(s.sims.count, 0)
    }

    func testWifiAndOneCellularWithUnknownInfo() throws {
        let s = try setUp(
            ssid: "Bob's Burgers Guest Wi-Fi",
            bssid: "ff:ee:dd:cc:bb:aa",
            networkType: .wifi,
            cellularNetworkType: nil,
            cellular: ["1": FakeCTCarrier()]
        )

        XCTAssertEqual(s.ssid?.UniqueID, "connectivity_ssid")
        XCTAssertEqual(s.ssid?.Name, "SSID")
        XCTAssertEqual(s.ssid?.State as? String, "Bob's Burgers Guest Wi-Fi")
        XCTAssertEqual(s.ssid?.Icon, "mdi:wifi")

        XCTAssertEqual(s.bssid?.UniqueID, "connectivity_bssid")
        XCTAssertEqual(s.bssid?.Name, "BSSID")
        XCTAssertEqual(s.bssid?.State as? String, "ff:ee:dd:cc:bb:aa")
        XCTAssertEqual(s.bssid?.Icon, "mdi:wifi-star")

        XCTAssertEqual(s.connection?.UniqueID, "connectivity_connection_type")
        XCTAssertEqual(s.connection?.Name, "Connection Type")
        XCTAssertEqual(s.connection?.State as? String, "Wi-Fi")
        XCTAssertEqual(s.connection?.Icon, "mdi:wifi")

        XCTAssertEqual(s.sims.count, 1)
        XCTAssertEqual(s.sims[0].UniqueID, "connectivity_cellular_provider")
        XCTAssertEqual(s.sims[0].Name, "Cellular Provider")
        XCTAssertEqual(s.sims[0].State as? String, "N/A")
        XCTAssertEqual(s.sims[0].Icon, "mdi:sim")
    }

    func testCellularBadRadioTech() throws {
        let s = try setUp(
            ssid: nil,
            bssid: nil,
            networkType: .cellular,
            cellularNetworkType: .wwan2g,
            cellular: [
                "1": with(FakeCTCarrier()) {
                    $0.overrideCarrierName = "Cellular1"
                }
            ],
            radioTech: [
                "1": "garbage value"
            ]
        )

        XCTAssertEqual(s.sims.count, 1)
        XCTAssertEqual(s.sims[0].UniqueID, "connectivity_cellular_provider")
        XCTAssertEqual(s.sims[0].Name, "Cellular Provider")
        XCTAssertEqual(s.sims[0].State as? String, "Cellular1")
        XCTAssertEqual(s.sims[0].Icon, "mdi:sim")
    }

    func testWifiAndTwoCellular() throws {
        let s = try setUp(
            ssid: "Bob's Burgers Guest Wi-Fi",
            bssid: "ff:ee:dd:cc:bb:aa",
            networkType: .wifi,
            cellularNetworkType: .wwan3g,
            cellular: [
                "1": with(FakeCTCarrier()) {
                    $0.overrideCarrierName = "Cellular1"
                },
                "2": with(FakeCTCarrier()) {
                    $0.overrideCarrierName = "Cellular2"
                }
            ],
            radioTech: [
                "1": CTRadioAccessTechnologyEdge,
                "2": CTRadioAccessTechnologyLTE
            ]
        )

        XCTAssertEqual(s.ssid?.UniqueID, "connectivity_ssid")
        XCTAssertEqual(s.ssid?.Name, "SSID")
        XCTAssertEqual(s.ssid?.State as? String, "Bob's Burgers Guest Wi-Fi")
        XCTAssertEqual(s.ssid?.Icon, "mdi:wifi")

        XCTAssertEqual(s.bssid?.UniqueID, "connectivity_bssid")
        XCTAssertEqual(s.bssid?.Name, "BSSID")
        XCTAssertEqual(s.bssid?.State as? String, "ff:ee:dd:cc:bb:aa")
        XCTAssertEqual(s.bssid?.Icon, "mdi:wifi-star")

        XCTAssertEqual(s.connection?.UniqueID, "connectivity_connection_type")
        XCTAssertEqual(s.connection?.Name, "Connection Type")
        XCTAssertEqual(s.connection?.State as? String, "Wi-Fi")
        XCTAssertEqual(s.connection?.Icon, "mdi:wifi")

        XCTAssertEqual(s.sims.count, 2)
        XCTAssertEqual(s.sims[0].UniqueID, "connectivity_sim_1")
        XCTAssertEqual(s.sims[0].Name, "SIM 1")
        XCTAssertEqual(s.sims[0].State as? String, "Cellular1")
        XCTAssertEqual(s.sims[0].Icon, "mdi:sim")

        XCTAssertEqual(s.sims[1].UniqueID, "connectivity_sim_2")
        XCTAssertEqual(s.sims[1].Name, "SIM 2")
        XCTAssertEqual(s.sims[1].State as? String, "Cellular2")
        XCTAssertEqual(s.sims[1].Icon, "mdi:sim")
    }

    func testNoWifiOneCellular() throws {
        let s = try setUp(
            ssid: nil,
            bssid: nil,
            networkType: .cellular,
            cellularNetworkType: .wwan4g,
            cellular: ["1": with(FakeCTCarrier()) {
                $0.overrideCarrierName = "Dinosaurs"
            }],
            radioTech: ["1": CTRadioAccessTechnologyLTE]
        )

        XCTAssertEqual(s.ssid?.UniqueID, "connectivity_ssid")
        XCTAssertEqual(s.ssid?.Name, "SSID")
        XCTAssertEqual(s.ssid?.State as? String, "Not Connected")
        XCTAssertEqual(s.ssid?.Icon, "mdi:wifi-off")

        XCTAssertEqual(s.bssid?.UniqueID, "connectivity_bssid")
        XCTAssertEqual(s.bssid?.Name, "BSSID")
        XCTAssertEqual(s.bssid?.State as? String, "Not Connected")
        XCTAssertEqual(s.bssid?.Icon, "mdi:wifi-off")

        XCTAssertEqual(s.connection?.UniqueID, "connectivity_connection_type")
        XCTAssertEqual(s.connection?.Name, "Connection Type")
        XCTAssertEqual(s.connection?.State as? String, "Cellular")
        XCTAssertEqual(s.connection?.Icon, "mdi:signal")
        XCTAssertEqual(s.connection?.Attributes?["Cellular Technology"] as? String, "4G")

        XCTAssertEqual(s.sims.count, 1)
        XCTAssertEqual(s.sims[0].UniqueID, "connectivity_cellular_provider")
        XCTAssertEqual(s.sims[0].Name, "Cellular Provider")
        XCTAssertEqual(s.sims[0].State as? String, "Dinosaurs")
        XCTAssertEqual(s.sims[0].Icon, "mdi:sim")
    }
}

private class FakeCTCarrier: CTCarrier {
    var overrideCarrierName: String?
    var overrideMobileCountryCode: String?
    var overrideMobileNetworkCode: String?
    var overrideIsoCountryCode: String?
    var overrideAllowsVOIP: Bool  = false

    override var carrierName: String? { overrideCarrierName }
    override var mobileCountryCode: String? { overrideMobileCountryCode }
    override var mobileNetworkCode: String? { overrideMobileNetworkCode }
    override var isoCountryCode: String? { overrideIsoCountryCode }
    override var allowsVOIP: Bool { overrideAllowsVOIP }
}
