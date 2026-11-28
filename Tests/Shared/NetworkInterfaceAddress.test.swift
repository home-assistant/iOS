import Foundation
@testable import Shared
import XCTest

class NetworkInterfaceAddressTests: XCTestCase {
    func testFormatsDottedDecimal() {
        let address = in_addr(s_addr: UInt32(bigEndian: 0xC0A8_B21B))
        XCTAssertEqual(NetworkInterfaceAddress.format(address), "192.168.178.27")
    }

    func testFormatsLowestAndHighestAddress() {
        XCTAssertEqual(NetworkInterfaceAddress.format(in_addr(s_addr: 0)), "0.0.0.0")
        XCTAssertEqual(NetworkInterfaceAddress.format(in_addr(s_addr: UInt32.max)), "255.255.255.255")
    }

    func testReadsAddressOfExistingInterface() {
        // Every Apple platform, simulators included, has a loopback interface that is always up.
        XCTAssertEqual(NetworkInterfaceAddress.ipv4(ofInterface: "lo0"), "127.0.0.1")
    }

    func testUnknownInterfaceHasNoAddress() {
        XCTAssertNil(NetworkInterfaceAddress.ipv4(ofInterface: "no-such-interface"))
    }
}
