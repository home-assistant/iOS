@testable import Shared
import XCTest

class DevicePoseTests: XCTestCase {
    private enum Orientation {
        static let unknown = 0
        static let portrait = 1
        static let portraitUpsideDown = 2
        static let landscapeLeft = 3
        static let landscapeRight = 4
        static let faceUp = 5
        static let faceDown = 6
    }

    private let allOrientations = Array(Orientation.unknown ... Orientation.faceDown)

    func testUnknownHingeIsUnknownWhateverTheOrientation() {
        for orientation in allOrientations {
            XCTAssertEqual(pose(.unknown, orientation), .unknown)
        }
    }

    func testClosedHingeIsClosedWhateverTheOrientation() {
        for orientation in allOrientations {
            XCTAssertEqual(pose(.closed, orientation), .closed)
        }
    }

    func testHingeTheSystemCallsClosedButIsOpenIsTreatedAsPartiallyOpen() {
        // An iPhone Duo standing as a narrow tent reports 30° and closed.
        XCTAssertEqual(pose(.closed, Orientation.landscapeRight, angle: 30), .tent)
        XCTAssertEqual(pose(.closed, Orientation.faceUp, angle: 30), .tent)
        XCTAssertEqual(pose(.closed, Orientation.landscapeLeft, angle: 30), .laptop)
        XCTAssertEqual(pose(.closed, Orientation.portrait, angle: 30), .book)
        XCTAssertEqual(pose(.closed, Orientation.unknown, angle: 30), .partiallyOpen)
    }

    func testHingeBarelyOpenIsStillClosed() {
        XCTAssertEqual(pose(.closed, Orientation.landscapeRight, angle: 9.9), .closed)
        XCTAssertEqual(pose(.closed, Orientation.landscapeRight, angle: 10), .tent)
    }

    func testPartiallyOpenUprightIsBook() {
        XCTAssertEqual(pose(.partiallyOpen, Orientation.portrait), .book)
        XCTAssertEqual(pose(.partiallyOpen, Orientation.portraitUpsideDown), .book)
    }

    func testPartiallyOpenSidewaysWithTheHingeDownIsLaptop() {
        XCTAssertEqual(pose(.partiallyOpen, Orientation.landscapeLeft), .laptop)
    }

    func testPartiallyOpenSidewaysWithTheHingeUpIsTent() {
        XCTAssertEqual(pose(.partiallyOpen, Orientation.landscapeRight), .tent)
    }

    func testPartiallyOpenWithTheOuterDisplayFacingUpIsTent() {
        XCTAssertEqual(pose(.partiallyOpen, Orientation.faceUp), .tent)
    }

    func testPartiallyOpenWithoutAnUprightOrientationIsPartiallyOpen() {
        for orientation in [Orientation.unknown, Orientation.faceDown, 99] {
            XCTAssertEqual(pose(.partiallyOpen, orientation), .partiallyOpen)
        }
    }

    func testFullyOpenFaceDownIsFlatFaceDown() {
        XCTAssertEqual(pose(.fullyOpen, Orientation.faceDown), .flatFaceDown)
    }

    func testFullyOpenWithTheHingeUprightIsFlatLandscape() {
        XCTAssertEqual(pose(.fullyOpen, Orientation.portrait), .flatLandscape)
        XCTAssertEqual(pose(.fullyOpen, Orientation.portraitUpsideDown), .flatLandscape)
    }

    func testFullyOpenWithTheHingeAcrossIsFlatPortrait() {
        XCTAssertEqual(pose(.fullyOpen, Orientation.landscapeLeft), .flatPortrait)
        XCTAssertEqual(pose(.fullyOpen, Orientation.landscapeRight), .flatPortrait)
    }

    func testFullyOpenWithoutAnUprightOrientationIsFlat() {
        for orientation in [Orientation.unknown, Orientation.faceUp, 99] {
            XCTAssertEqual(pose(.fullyOpen, orientation), .flat)
        }
    }

    func testRawValuesAreStable() {
        XCTAssertEqual(DevicePose.unknown.rawValue, "unknown")
        XCTAssertEqual(DevicePose.closed.rawValue, "closed")
        XCTAssertEqual(DevicePose.book.rawValue, "book")
        XCTAssertEqual(DevicePose.laptop.rawValue, "laptop")
        XCTAssertEqual(DevicePose.tent.rawValue, "tent")
        XCTAssertEqual(DevicePose.partiallyOpen.rawValue, "partially_open")
        XCTAssertEqual(DevicePose.flat.rawValue, "flat")
        XCTAssertEqual(DevicePose.flatPortrait.rawValue, "flat_portrait")
        XCTAssertEqual(DevicePose.flatLandscape.rawValue, "flat_landscape")
        XCTAssertEqual(DevicePose.flatFaceDown.rawValue, "flat_face_down")
    }

    private func pose(_ status: HingeStatus, _ orientation: Int, angle: Double = 0) -> DevicePose {
        DevicePose(state: HingeState(angleDegrees: angle, status: status), uiDeviceOrientationRawValue: orientation)
    }
}
