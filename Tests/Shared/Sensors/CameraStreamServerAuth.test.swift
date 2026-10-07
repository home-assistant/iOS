@testable import Shared
import XCTest

#if os(iOS) && !targetEnvironment(macCatalyst)
class CameraStreamServerAuthTests: XCTestCase {
    private func request(withAuthorization value: String?) -> String {
        var lines = ["GET /camera HTTP/1.1", "Host: 192.168.1.2:8090"]
        if let value {
            lines.append("Authorization: \(value)")
        }
        lines.append("")
        lines.append("")
        return lines.joined(separator: "\r\n")
    }

    private func basicHeader(username: String, password: String) -> String {
        let encoded = Data("\(username):\(password)".utf8).base64EncodedString()
        return "Basic \(encoded)"
    }

    func testNoCredentialsConfiguredAllowsAnyRequest() {
        XCTAssertTrue(CameraStreamServer.isAuthorized(
            request: request(withAuthorization: nil),
            username: "",
            password: ""
        ))
    }

    func testConfiguredCredentialsRejectMissingHeader() {
        XCTAssertFalse(CameraStreamServer.isAuthorized(
            request: request(withAuthorization: nil),
            username: "kiosk",
            password: "secret"
        ))
    }

    func testConfiguredCredentialsAcceptMatchingHeader() {
        XCTAssertTrue(CameraStreamServer.isAuthorized(
            request: request(withAuthorization: basicHeader(username: "kiosk", password: "secret")),
            username: "kiosk",
            password: "secret"
        ))
    }

    func testConfiguredCredentialsRejectWrongPassword() {
        XCTAssertFalse(CameraStreamServer.isAuthorized(
            request: request(withAuthorization: basicHeader(username: "kiosk", password: "wrong")),
            username: "kiosk",
            password: "secret"
        ))
    }

    func testOnlyPasswordConfiguredStillRequiresAuth() {
        XCTAssertFalse(CameraStreamServer.isAuthorized(
            request: request(withAuthorization: nil),
            username: "",
            password: "secret"
        ))
        XCTAssertTrue(CameraStreamServer.isAuthorized(
            request: request(withAuthorization: basicHeader(username: "", password: "secret")),
            username: "",
            password: "secret"
        ))
    }

    func testMalformedBase64IsRejected() {
        XCTAssertFalse(CameraStreamServer.isAuthorized(
            request: request(withAuthorization: "Basic not-base-64!!"),
            username: "kiosk",
            password: "secret"
        ))
    }

    func testHeaderNameAndSchemeAreCaseInsensitive() {
        let encoded = Data("kiosk:secret".utf8).base64EncodedString()
        let raw = "GET / HTTP/1.1\r\nauthorization: basic \(encoded)\r\n\r\n"
        XCTAssertTrue(CameraStreamServer.isAuthorized(request: raw, username: "kiosk", password: "secret"))
    }

    func testBasicAuthCredentialsParsesUsernameAndPassword() {
        let credentials = CameraStreamServer.basicAuthCredentials(
            fromRequest: request(withAuthorization: basicHeader(username: "user", password: "p:ss"))
        )
        XCTAssertEqual(credentials?.username, "user")
        XCTAssertEqual(credentials?.password, "p:ss")
    }

    func testBasicAuthCredentialsReturnsNilWithoutHeader() {
        XCTAssertNil(CameraStreamServer.basicAuthCredentials(fromRequest: request(withAuthorization: nil)))
    }
}
#endif
