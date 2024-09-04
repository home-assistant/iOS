@testable import Shared
import XCTest

final class WidgetsKindTests: XCTestCase {
    func testWidgetsKindCasesValues() {
        XCTAssertEqual(WidgetsKind.assist.rawValue, "WidgetAssist")
        XCTAssertEqual(WidgetsKind.actions.rawValue, "WidgetActions")
        XCTAssertEqual(WidgetsKind.openPage.rawValue, "WidgetOpenPage")
        XCTAssertEqual(WidgetsKind.gauge.rawValue, "WidgetGauge")
        XCTAssertEqual(WidgetsKind.details.rawValue, "WidgetDetails")
        XCTAssertEqual(WidgetsKind.scripts.rawValue, "WidgetScripts")
        XCTAssertEqual(WidgetsKind.controlScript.rawValue, "ControlScript")
        XCTAssertEqual(WidgetsKind.controlScene.rawValue, "ControlScene")
        XCTAssertEqual(WidgetsKind.controlAssist.rawValue, "ControlAssist")
        XCTAssertEqual(WidgetsKind.controlOpenPage.rawValue, "ControlOpenPage")
        XCTAssertEqual(WidgetsKind.allCases.count, 10)
    }
}
