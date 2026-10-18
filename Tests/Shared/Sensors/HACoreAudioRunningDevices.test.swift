@testable import Shared
import XCTest

class HACoreAudioRunningDevicesTests: XCTestCase {
    private let device: UInt32 = 42

    func testRecordingWhenAProcessRecordsFromIt() {
        let running = HACoreAudioRunningDevices(inputDeviceIDs: [device], outputDeviceIDs: [])

        XCTAssertTrue(running.isRecording(deviceID: device, isRunningSomewhere: true))
        XCTAssertFalse(running.isPlayingBack(deviceID: device, isRunningSomewhere: true))
    }

    func testPlayingBackWhenAProcessPlaysThroughIt() {
        let running = HACoreAudioRunningDevices(inputDeviceIDs: [], outputDeviceIDs: [device])

        XCTAssertTrue(running.isPlayingBack(deviceID: device, isRunningSomewhere: true))
        XCTAssertFalse(running.isRecording(deviceID: device, isRunningSomewhere: true))
    }

    /// A headset recording and playing back at once is in use in both directions.
    func testBothDirectionsWhenAProcessClaimsItForEach() {
        let running = HACoreAudioRunningDevices(inputDeviceIDs: [device], outputDeviceIDs: [device])

        XCTAssertTrue(running.isRecording(deviceID: device, isRunningSomewhere: true))
        XCTAssertTrue(running.isPlayingBack(deviceID: device, isRunningSomewhere: true))
    }

    /// Nothing claims the device, so the device-global flag is all there is to go on.
    func testFallsBackToTheGlobalFlagWhenUnclaimed() {
        let running = HACoreAudioRunningDevices(inputDeviceIDs: [1], outputDeviceIDs: [2])

        XCTAssertTrue(running.isRecording(deviceID: device, isRunningSomewhere: true))
        XCTAssertTrue(running.isPlayingBack(deviceID: device, isRunningSomewhere: true))
        XCTAssertFalse(running.isRecording(deviceID: device, isRunningSomewhere: false))
        XCTAssertFalse(running.isPlayingBack(deviceID: device, isRunningSomewhere: false))
    }

    func testNothingRunsWhenNoProcessIsDoingIO() {
        let running = HACoreAudioRunningDevices(inputDeviceIDs: [], outputDeviceIDs: [])

        XCTAssertFalse(running.isRecording(deviceID: device, isRunningSomewhere: false))
        XCTAssertFalse(running.isPlayingBack(deviceID: device, isRunningSomewhere: false))
    }
}
