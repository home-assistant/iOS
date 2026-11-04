@testable import Shared
import XCTest

#if os(iOS) && !targetEnvironment(macCatalyst)
class MotionDetectionManagerTests: XCTestCase {
    func testChangedRatioEmptyBuffers() {
        XCTAssertEqual(MotionDetectionManager.changedRatio(previous: [], current: []), 0)
    }

    func testChangedRatioMismatchedSizes() {
        XCTAssertEqual(MotionDetectionManager.changedRatio(previous: [0, 0], current: [0]), 0)
    }

    func testChangedRatioIdenticalFrames() {
        XCTAssertEqual(MotionDetectionManager.changedRatio(previous: [10, 20, 30], current: [10, 20, 30]), 0)
    }

    func testChangedRatioRespectsPixelThreshold() {
        // The per-pixel threshold is 25: a delta of exactly 25 is not a change, 26 is.
        let ratio = MotionDetectionManager.changedRatio(
            previous: [0, 0, 0, 0],
            current: [0, 25, 26, 255]
        )
        XCTAssertEqual(ratio, 0.5)
    }

    func testChangedRatioAllPixelsChanged() {
        XCTAssertEqual(MotionDetectionManager.changedRatio(previous: [0, 0], current: [255, 255]), 1)
    }
}
#endif
