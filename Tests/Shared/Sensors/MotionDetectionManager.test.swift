@testable import Shared
import XCTest

#if os(iOS) && !targetEnvironment(macCatalyst)
import AVFoundation
import UIKit

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

    // The landscape cases deliberately cross over: rotating the device left aims the
    // camera out of what AVFoundation calls the right-hand landscape. Getting this
    // backwards is what makes a stream come out upside down.
    func testVideoOrientationForDeviceOrientation() {
        XCTAssertEqual(MotionDetectionManager.videoOrientation(for: .portrait), .portrait)
        XCTAssertEqual(MotionDetectionManager.videoOrientation(for: .portraitUpsideDown), .portraitUpsideDown)
        XCTAssertEqual(MotionDetectionManager.videoOrientation(for: .landscapeLeft), .landscapeRight)
        XCTAssertEqual(MotionDetectionManager.videoOrientation(for: .landscapeRight), .landscapeLeft)
    }

    /// A flat or wall-mounted tablet reports these, and they say nothing about which
    /// way is up — the caller falls back to the screen's rotation.
    func testVideoOrientationWithoutAnUpDirection() {
        XCTAssertNil(MotionDetectionManager.videoOrientation(for: .faceUp))
        XCTAssertNil(MotionDetectionManager.videoOrientation(for: .faceDown))
        XCTAssertNil(MotionDetectionManager.videoOrientation(for: .unknown))
    }

    /// Every device orientation should map to a distinct video orientation — an
    /// accidental collision would silently leave one rotation broken.
    func testEveryRotationIsDistinct() {
        let orientations: [UIDeviceOrientation] = [.portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight]
        let mapped = orientations.compactMap(MotionDetectionManager.videoOrientation(for:))
        XCTAssertEqual(Set(mapped.map(\.rawValue)).count, orientations.count)
    }
}
#endif
