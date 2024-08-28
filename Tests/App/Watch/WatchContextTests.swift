@testable import Shared
import XCTest

final class WatchContextTests: XCTestCase {
    func testWatchContextCases() {
        XCTAssertEqual(WatchContext.allCases.count, 8)
        XCTAssertEqual(WatchContext.servers.rawValue, "servers")
        XCTAssertEqual(WatchContext.complications.rawValue, "complications")
        XCTAssertEqual(WatchContext.ssid.rawValue, "SSID")
        XCTAssertEqual(WatchContext.activeFamilies.rawValue, "activeFamilies")
        XCTAssertEqual(WatchContext.watchModel.rawValue, "watchModel")
        XCTAssertEqual(WatchContext.watchVersion.rawValue, "watchVersion")
        XCTAssertEqual(WatchContext.watchBattery.rawValue, "watchBattery")
        XCTAssertEqual(WatchContext.watchBatteryState.rawValue, "watchBatteryState")
    }
}
