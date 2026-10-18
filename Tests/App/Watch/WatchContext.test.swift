@testable import Shared
import XCTest

final class WatchContextTests: XCTestCase {
    func testWatchContextCases() {
        XCTAssertEqual(WatchContext.allCases.count, 6)
        XCTAssertEqual(WatchContext.servers.rawValue, "servers")
        XCTAssertEqual(WatchContext.complications.rawValue, "complications")
        XCTAssertEqual(WatchContext.complicationConfigs.rawValue, "complicationConfigs")
        XCTAssertEqual(WatchContext.activeFamilies.rawValue, "activeFamilies")
        XCTAssertEqual(WatchContext.watchModel.rawValue, "watchModel")
        XCTAssertEqual(WatchContext.watchVersion.rawValue, "watchVersion")
    }
}
