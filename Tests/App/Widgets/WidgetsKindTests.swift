@testable import Shared
import XCTest

final class WidgetsKindTests: XCTestCase {
    func testWidgetsKindCasesValues() {
        XCTAssertEqual(WidgetsKind.assist.rawValue, "WidgetAssist")
        XCTAssertEqual(WidgetsKind.actions.rawValue, "WidgetActions")
        XCTAssertEqual(WidgetsKind.openPage.rawValue, "WidgetOpenPage")
        XCTAssertEqual(WidgetsKind.gauge.rawValue, "WidgetGauge")
        XCTAssertEqual(WidgetsKind.details.rawValue, "WidgetDetails")
        XCTAssertEqual(WidgetsKind.allCases.count, 5)
    }
}
