@testable import Shared
import XCTest

final class WidgetsKindTests: XCTestCase {
    func testWidgetsKindCasesValues() {
        // Widgets
        XCTAssertEqual(WidgetsKind.assist.rawValue, "WidgetAssist")
        XCTAssertEqual(WidgetsKind.actions.rawValue, "WidgetActions")
        XCTAssertEqual(WidgetsKind.openPage.rawValue, "WidgetOpenPage")
        XCTAssertEqual(WidgetsKind.gauge.rawValue, "WidgetGauge")
        XCTAssertEqual(WidgetsKind.details.rawValue, "WidgetDetails")
        XCTAssertEqual(WidgetsKind.scripts.rawValue, "WidgetScripts")
        XCTAssertEqual(WidgetsKind.sensors.rawValue, "sensors")
        XCTAssertEqual(WidgetsKind.custom.rawValue, "custom")

        // Controls
        XCTAssertEqual(WidgetsKind.controlScript.rawValue, "controlScript")
        XCTAssertEqual(WidgetsKind.controlScene.rawValue, "controlScene")
        XCTAssertEqual(WidgetsKind.controlAssist.rawValue, "controlAssist")
        XCTAssertEqual(WidgetsKind.controlOpenPage.rawValue, "controlOpenPage")
        XCTAssertEqual(WidgetsKind.controlLight.rawValue, "controlLight")
        XCTAssertEqual(WidgetsKind.controlSwitch.rawValue, "controlSwitch")
        XCTAssertEqual(WidgetsKind.controlCover.rawValue, "controlCover")
        XCTAssertEqual(WidgetsKind.controlOpenEntity.rawValue, "controlOpenEntity")
        XCTAssertEqual(WidgetsKind.controlOpenCamera.rawValue, "controlOpenCamera")
        XCTAssertEqual(WidgetsKind.controlOpenLock.rawValue, "controlOpenLock")
        XCTAssertEqual(WidgetsKind.controlOpenCoverEntity.rawValue, "controlOpenCoverEntity")
        XCTAssertEqual(WidgetsKind.allCases.count, 19)
    }
}
