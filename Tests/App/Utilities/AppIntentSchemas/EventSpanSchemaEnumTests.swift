@testable import HomeAssistant
import XCTest

/// How the span Siri asks for maps onto Home Assistant's `recurrence_range`.
@available(iOS 27.0, *)
final class EventSpanSchemaEnumTests: XCTestCase {
    /// Home Assistant only distinguishes "this one" from "this and everything after"; every
    /// occurrence is addressed by the uid with no range at all, so `.all` cannot send an empty one.
    func testOnlyASingleOccurrenceHasNoRange() {
        XCTAssertNil(EventSpanSchemaEnum.this.recurrenceRange)
        XCTAssertEqual(EventSpanSchemaEnum.future.recurrenceRange, "THISANDFUTURE")
        XCTAssertEqual(EventSpanSchemaEnum.all.recurrenceRange, "THISANDFUTURE")
    }

    func testEveryCaseIsNamedForThePicker() {
        for span in [EventSpanSchemaEnum.this, .future, .all] {
            XCTAssertNotNil(
                EventSpanSchemaEnum.caseDisplayRepresentations[span],
                "expected \(span.rawValue) to have a display representation"
            )
        }
        XCTAssertEqual(EventSpanSchemaEnum.caseDisplayRepresentations.count, 3)
    }
}
