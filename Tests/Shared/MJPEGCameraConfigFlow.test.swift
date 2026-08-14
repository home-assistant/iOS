@testable import Shared
import XCTest

class MJPEGCameraConfigFlowTests: XCTestCase {
    func testUserInputWithoutCredentials() {
        let input = MJPEGCameraConfigFlow.userInput(
            name: "iPhone Camera",
            streamURL: "http://192.168.1.2:8090/camera",
            username: "",
            password: ""
        )

        XCTAssertEqual(input["name"] as? String, "iPhone Camera")
        XCTAssertEqual(input["mjpeg_url"] as? String, "http://192.168.1.2:8090/camera")
        XCTAssertEqual(input["password"] as? String, "")
        XCTAssertEqual(input["verify_ssl"] as? Bool, true)
        XCTAssertNil(input["username"])
        XCTAssertNil(input["still_image_url"])
    }

    func testUserInputWithCredentials() {
        let input = MJPEGCameraConfigFlow.userInput(
            name: "iPad Camera",
            streamURL: "http://192.168.1.3:8090/camera",
            username: "ha",
            password: "hunter2"
        )

        XCTAssertEqual(input["username"] as? String, "ha")
        XCTAssertEqual(input["password"] as? String, "hunter2")
    }

    func testUserInputIsJSONSerializable() throws {
        let input = MJPEGCameraConfigFlow.userInput(
            name: "iPhone Camera",
            streamURL: "http://192.168.1.2:8090/camera",
            username: "ha",
            password: "hunter2"
        )
        XCTAssertNoThrow(try JSONSerialization.data(withJSONObject: input, options: []))
    }
}
