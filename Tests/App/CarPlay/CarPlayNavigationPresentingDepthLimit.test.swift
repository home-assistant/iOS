import CarPlay
@testable import HomeAssistant
import XCTest

/// CarPlay raises past five stacked templates, which takes the app down, so pushes that would get
/// there are refused instead.
final class CarPlayNavigationPresentingDepthLimitTests: XCTestCase {
    private var navigator: FakeCarPlayNavigator!

    override func setUp() {
        super.setUp()
        navigator = FakeCarPlayNavigator()
    }

    override func tearDown() {
        navigator = nil
        super.tearDown()
    }

    private func template(_ title: String) -> CPListTemplate {
        CPListTemplate(title: title, sections: [])
    }

    func testPushesWhileTheStackHasRoom() {
        var outcome: (Bool, Error?)?
        navigator.pushTemplateWithinDepthLimit(template("one"), animated: false) { outcome = ($0, $1) }

        XCTAssertEqual(navigator.pushedTemplates.count, 1)
        XCTAssertEqual(outcome?.0, true)
        XCTAssertNil(outcome?.1)
    }

    func testRefusesTheTemplateThatWouldExceedTheLimit() {
        for index in 0 ..< FakeCarPlayNavigator.maximumTemplateDepth {
            navigator.pushTemplateWithinDepthLimit(template("\(index)"), animated: false)
        }
        XCTAssertEqual(navigator.templates.count, FakeCarPlayNavigator.maximumTemplateDepth)

        var outcome: (Bool, Error?)?
        navigator.pushTemplateWithinDepthLimit(template("one too many"), animated: false) { outcome = ($0, $1) }

        XCTAssertEqual(navigator.pushedTemplates.count, FakeCarPlayNavigator.maximumTemplateDepth)
        XCTAssertEqual(outcome?.0, false)
        XCTAssertNil(outcome?.1)
    }

    func testPoppingMakesRoomAgain() {
        for index in 0 ..< FakeCarPlayNavigator.maximumTemplateDepth {
            navigator.pushTemplateWithinDepthLimit(template("\(index)"), animated: false)
        }
        navigator.popTemplate(animated: false, completion: nil)

        navigator.pushTemplateWithinDepthLimit(template("after pop"), animated: false)

        XCTAssertEqual(navigator.pushedTemplates.count, FakeCarPlayNavigator.maximumTemplateDepth + 1)
        XCTAssertEqual(navigator.templates.count, FakeCarPlayNavigator.maximumTemplateDepth)
    }

    func testRefusesATemplateAlreadyOnTheStack() {
        let repeated = template("repeated")
        navigator.pushTemplateWithinDepthLimit(repeated, animated: false)

        var outcome: (Bool, Error?)?
        navigator.pushTemplateWithinDepthLimit(repeated, animated: false) { outcome = ($0, $1) }

        XCTAssertEqual(navigator.pushedTemplates.count, 1)
        XCTAssertEqual(outcome?.0, false)
        XCTAssertNil(outcome?.1)
    }

    func testPopToRootKeepsOnlyTheRoot() {
        for index in 0 ..< 3 {
            navigator.pushTemplateWithinDepthLimit(template("\(index)"), animated: false)
        }
        navigator.popToRootTemplate(animated: false, completion: nil)

        XCTAssertEqual(navigator.templates.count, 1)
    }
}
