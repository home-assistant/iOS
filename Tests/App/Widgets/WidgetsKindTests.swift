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
        XCTAssertEqual(WidgetsKind.controlScript.rawValue, "controlScript")
        XCTAssertEqual(WidgetsKind.controlScene.rawValue, "controlScene")
        XCTAssertEqual(WidgetsKind.controlAssist.rawValue, "controlAssist")
        XCTAssertEqual(WidgetsKind.controlOpenPage.rawValue, "controlOpenPage")
        XCTAssertEqual(WidgetsKind.controlLight.rawValue, "controlLight")
        XCTAssertEqual(WidgetsKind.allCases.count, 11)
    }
}
