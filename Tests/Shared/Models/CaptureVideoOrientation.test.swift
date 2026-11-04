@testable import Shared
import XCTest

#if os(iOS)
import AVFoundation
import UIKit

class CaptureVideoOrientationTests: XCTestCase {
    // The landscape cases deliberately cross over: rotating the device left aims the
    // camera out of what AVFoundation calls the right-hand landscape. Getting this
    // backwards is what makes a stream come out upside down.
    func testFromDeviceOrientation() {
        XCTAssertEqual(AVCaptureVideoOrientation(deviceOrientation: .portrait), .portrait)
        XCTAssertEqual(AVCaptureVideoOrientation(deviceOrientation: .portraitUpsideDown), .portraitUpsideDown)
        XCTAssertEqual(AVCaptureVideoOrientation(deviceOrientation: .landscapeLeft), .landscapeRight)
        XCTAssertEqual(AVCaptureVideoOrientation(deviceOrientation: .landscapeRight), .landscapeLeft)
    }

    /// A flat or wall-mounted tablet reports these, and they say nothing about which
    /// way is up — callers need to fall back to the screen's rotation.
    func testDeviceOrientationWithoutAnUpDirection() {
        XCTAssertNil(AVCaptureVideoOrientation(deviceOrientation: .faceUp))
        XCTAssertNil(AVCaptureVideoOrientation(deviceOrientation: .faceDown))
        XCTAssertNil(AVCaptureVideoOrientation(deviceOrientation: .unknown))
    }

    /// Every device orientation should map to a distinct video orientation — an
    /// accidental collision would silently leave one rotation broken.
    func testEveryRotationIsDistinct() {
        let orientations: [UIDeviceOrientation] = [.portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight]
        let mapped = orientations.compactMap(AVCaptureVideoOrientation.init(deviceOrientation:))
        XCTAssertEqual(Set(mapped.map(\.rawValue)).count, orientations.count)
    }
}
#endif
