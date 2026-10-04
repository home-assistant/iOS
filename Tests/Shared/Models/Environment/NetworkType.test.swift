#if os(iOS) && !targetEnvironment(macCatalyst)
import CoreTelephony
import Foundation
@testable import Shared
import XCTest

final class NetworkTypeTests: XCTestCase {
    func testDescriptionsAndIcons() {
        let expected: [NetworkType: (description: String, icon: String)] = [
            .unknown: ("Unknown", "mdi:help-circle"),
            .noConnection: ("No Connection", "mdi:sim-off"),
            .wifi: ("Wi-Fi", "mdi:wifi"),
            .cellular: ("Cellular", "mdi:signal"),
            .ethernet: ("Ethernet", "mdi:ethernet"),
            .wwan2g: ("2G", "mdi:signal-2g"),
            .wwan3g: ("3G", "mdi:signal-3g"),
            .wwan4g: ("4G", "mdi:signal-4g"),
            .wwan5g: ("5G", "mdi:signal-5g"),
            .unknownTechnology: ("Unknown Technology", "mdi:help-circle"),
        ]

        XCTAssertEqual(expected.count, NetworkType.allCases.count)
        for type in NetworkType.allCases {
            XCTAssertEqual(type.description, expected[type]?.description)
            XCTAssertEqual(type.icon, expected[type]?.icon)
        }
    }

    func testRadioAccessTechnologies() {
        XCTAssertEqual(NetworkType(CTRadioAccessTechnologyNR), .wwan5g)
        XCTAssertEqual(NetworkType(CTRadioAccessTechnologyNRNSA), .wwan5g)

        for technology in [CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x] {
            XCTAssertEqual(NetworkType(technology), .wwan2g)
        }

        for technology in [
            CTRadioAccessTechnologyWCDMA,
            CTRadioAccessTechnologyHSDPA,
            CTRadioAccessTechnologyHSUPA,
            CTRadioAccessTechnologyCDMAEVDORev0,
            CTRadioAccessTechnologyCDMAEVDORevA,
            CTRadioAccessTechnologyCDMAEVDORevB,
            CTRadioAccessTechnologyeHRPD,
        ] {
            XCTAssertEqual(NetworkType(technology), .wwan3g)
        }

        XCTAssertEqual(NetworkType(CTRadioAccessTechnologyLTE), .wwan4g)
        XCTAssertEqual(NetworkType("CTRadioAccessTechnologySomethingNew"), .unknownTechnology)
    }

    func testReachabilityReportsAPlainNetworkType() {
        let reachability = NetworkReachability()

        let simple = reachability.getSimpleNetworkType()
        XCTAssertTrue([.noConnection, .wifi, .cellular].contains(simple))

        let detailed = reachability.getNetworkType()
        switch simple {
        case .noConnection, .wifi:
            XCTAssertEqual(detailed, simple)
        default:
            XCTAssertNotEqual(detailed, .noConnection)
        }

        XCTAssertNotEqual(NetworkReachability.getWWANNetworkType(), .unknownTechnology)
    }
}
#endif
