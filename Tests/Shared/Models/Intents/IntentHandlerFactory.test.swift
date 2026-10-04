import Foundation
import Intents
@testable import Shared
import XCTest

final class IntentHandlerFactoryTests: XCTestCase {
    func testFocusStatusIntentIsHandledByTheFocusHandler() {
        let handler = IntentHandlerFactory.handler(for: INShareFocusStatusIntent(focusStatus: nil))

        XCTAssertTrue(handler is FocusStatusIntentHandler)
    }

    /// Anything else falls back to the factory itself, which handles nothing.
    func testOtherIntentsFallBackToTheFactory() {
        let handler = IntentHandlerFactory.handler(for: INSendMessageIntent())

        XCTAssertTrue(handler is IntentHandlerFactory.Type)
        XCTAssertFalse(handler is FocusStatusIntentHandler)
    }
}
